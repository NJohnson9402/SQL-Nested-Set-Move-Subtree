--Preview Cats
SELECT *, ROW_NUMBER() OVER (PARTITION BY ParentID ORDER BY PLeft) AS SiblingSort
FROM NsmCat
ORDER BY PLeft;

--Add Depth
ALTER TABLE NsmCat ADD Depth INT NULL;

UPDATE NsmCat SET Depth = 0
WHERE ParentID IS NULL;

UPDATE NsmCat SET Depth = 1
WHERE ParentID = 1;

UPDATE NsmCat SET Depth = 2
WHERE ParentID IN (2, 3);

UPDATE NsmCat SET Depth = 3
WHERE ParentID IN (4,5,6,7,8);

--Now view with formatted Name to make it more tree-like
SELECT CatID, ParentID
	, REPLICATE(' > ', Depth) + Name AS DisplayName
	, PLeft, PRight
	, ROW_NUMBER() OVER (PARTITION BY ParentID ORDER BY PLeft) AS SiblingSort
FROM NsmCat
ORDER BY PLeft;

/* desired results:
CatID       ParentID    DisplayName    
----------- ----------- ---------------
1           NULL        Muffin         
2           1            > Stripes     
4           2            >  > Tigger   
6           2            >  > Simon    
5           2            >  > Jack     
9           5            >  >  > Smush 
10          5            >  >  > Smash 
3           1            > Fluffy      
7           3            >  > Mittens  
8           3            >  > Widget   

(10 row(s) affected)
*/

--There's a smarter way to initialize Depth... recursive CTE!
--And let's materialize SiblingSort (just called "Sort") while we're at it, for easy querying.
ALTER TABLE NsmCat ADD Sort INT NULL;
UPDATE NsmCat SET Depth = 0;

;WITH CatTree AS
(
	SELECT CatID, ParentID, Name
		, PLeft, PRight, Depth = 0
		, Sort = ROW_NUMBER() OVER (PARTITION BY ParentID ORDER BY PLeft)
	FROM NsmCat
	WHERE ParentID IS NULL

	UNION ALL
	
	SELECT cat.CatID, cat.ParentID, cat.Name
		, cat.PLeft, cat.PRight, Depth = tree.Depth + 1
		, Sort = ROW_NUMBER() OVER (PARTITION BY cat.ParentID ORDER BY cat.PLeft)
	FROM CatTree tree
	JOIN NsmCat cat
			ON cat.ParentID = tree.CatID
)
UPDATE cat SET cat.Sort = CatTree.Sort, cat.Depth = CatTree.Depth
FROM CatTree
JOIN NsmCat cat
		ON cat.CatID = CatTree.CatID

--And let's see the results...
SELECT CatID, ParentID
	, REPLICATE(' > ', Depth) + Name AS DisplayName
	, PLeft, PRight
	, Depth, Sort
FROM NsmCat
ORDER BY PLeft;

/* desired results:
CatID       ParentID    DisplayName    
----------- ----------- ---------------
1           NULL        Muffin         
2           1            > Stripes     
4           2            >  > Tigger   
6           2            >  > Simon    
5           2            >  > Jack     
9           5            >  >  > Smush 
10          5            >  >  > Smash 
3           1            > Fluffy      
7           3            >  > Mittens  
8           3            >  > Widget   

(10 row(s) affected)
*/

--It's like a tree-view!  Beautiful.

--Now, we didn't include Depth or Sort maintenance in our MoveCatSubtree routine (yet), but we can use them to check our work by re-populating them (using the above) after attempting a move.  Let's do that...

--Move Jack & children to under Mittens.
EXEC dbo.MoveCatSubtree @CatID = 5, @NewParentID = 7;
--> undo / move back to original position: EXEC dbo.MoveCatSubtree @CatID = 5, @NewParentID = 2;

--Repopulate Depth & Sort using the CTE-update above, then check results:
SELECT CatID, ParentID
	, REPLICATE(' > ', Depth) + Name AS DisplayName
	, PLeft, PRight
	, Depth, Sort
FROM NsmCat
ORDER BY PLeft;

/* desired results:
CatID       ParentID    DisplayName       
----------- ----------- ------------------
1           NULL        Muffin            
2           1            > Stripes        
4           2            >  > Tigger      
6           2            >  > Simon       
3           1            > Fluffy         
7           3            >  > Mittens     
5           7            >  >  > Jack     
9           5            >  >  >  > Smush 
10          5            >  >  >  > Smash 
8           3            >  > Widget      

(10 row(s) affected)
*/
