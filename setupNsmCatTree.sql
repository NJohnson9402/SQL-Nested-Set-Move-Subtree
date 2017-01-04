--Create the Cats table (NsmCat)
CREATE TABLE NsmCat (
	CatID INT NOT NULL IDENTITY(1,1)
		CONSTRAINT PK_NsmCat PRIMARY KEY (CatID)
	, ParentID INT NULL
	, Name VARCHAR(50) NOT NULL
	, PLeft INT NOT NULL
	, PRight INT NOT NULL
);

--Fill with test data
--> TRUNCATE TABLE NsmCat; --Use for repeated runs
INSERT INTO NsmCat (ParentID, Name, PLeft, PRight)
SELECT NULL AS ParentID, 'Muffin' AS Name, 1 AS PLeft, 20 AS PRight
UNION
SELECT 1, 'Stripes', 2, 13
UNION
SELECT 1, 'Fluffy', 14, 19
UNION
SELECT 2, 'Tigger', 3, 4
UNION
SELECT 2, 'Jack', 5, 10
UNION
SELECT 2, 'Simon', 11, 12
UNION
SELECT 3, 'Mittens', 15, 16
UNION
SELECT 3, 'Widget', 17, 18
UNION
SELECT 5, 'Smush', 6, 7
UNION
SELECT 5, 'Smash', 8, 9
ORDER BY ParentID, PLeft;

--Preview in "reading" order (top to bottom, left to right)
SELECT *, ROW_NUMBER() OVER (PARTITION BY ParentID ORDER BY PLeft) AS SiblingSort
FROM NsmCat
ORDER BY ParentID, PLeft;

--> This isn't very "tree-like" to look at... but for now, we're just testing our MoveSubtree method.
--> We'll add a [Depth] column later and then we can use it to format the Names nicely for grid-viewing.
