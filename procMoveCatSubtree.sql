IF NOT EXISTS (SELECT * FROM sys.objects WHERE [type] = 'P' AND [object_id] = OBJECT_ID('dbo.[MoveCatSubtree]'))
	EXEC('CREATE PROCEDURE dbo.[MoveCatSubtree] AS BEGIN SET NOCOUNT ON; END')
GO
--=============================================
--Author: NJohnson9402
--Created: 20170104
--Description: move a "subtree" in the NsmCat table to a new Parent node,
--& maintain NSM (Nested Set Model) position values.
--=============================================
ALTER PROCEDURE [dbo].[MoveCatSubtree]
	@CatID INT
	, @NewParentID INT
AS
BEGIN
	SET NOCOUNT ON;

	--Treat 0 & -1 the same: means we want to make the top of this subtree a Root node
	IF @NewParentID = 0
	BEGIN
		SET @NewParentID = -1;
	END

	--Cannot move a subtree under itself
	IF @NewParentID IN (
		SELECT SubCat.CatID
		FROM NsmCat Cat
		JOIN NsmCat SubCat
				ON SubCat.PLeft BETWEEN Cat.PLeft AND Cat.PRight
		WHERE Cat.CatID = @CatID)
	BEGIN
		RAISERROR (N'Cannot move subtree to a node within itself.', 18, 1);
		RETURN;
	END

	--Cannot move subtree to a node that doesnt exist
	IF NOT EXISTS(SELECT 1 FROM NsmCat WHERE CatID = @NewParentID) AND @NewParentID <> -1
	BEGIN
		RAISERROR (N'Cannot move subtree to a node that doesn''t exist.', 18, 1);
		RETURN;
	END

	--Cannot move subtree that doesnt exist
	IF NOT EXISTS(SELECT 1 FROM NsmCat WHERE CatID = @CatID )
	BEGIN
		RAISERROR (N'Cannot move subtree that doesn''t exist.', 18, 1);
		RETURN;
	END

	--Get old Parent & Subtree size
	DECLARE @OldParentID INT
		, @SubtreeSize INT
		, @SubtreeOldLeft INT
		, @SubtreeOldRight INT

	SELECT @OldParentID = ParentID,  @SubtreeSize = PRight - PLeft + 1
		, @SubtreeOldLeft = PLeft, @SubtreeOldRight = PRight
	FROM NsmCat
	WHERE CatID = @CatID

	--Cannot move subtree to its own Parent, i.e. there's nothing to do b/c new parent is same as old
	IF @OldParentID = @NewParentID
	BEGIN
		RAISERROR (N'Cannot move subtree to its own parent.', 18, 1);
		RETURN;
	END

	--Get new Parent position
	DECLARE @NewParentRight INT;

	--If we're going Root, place it to the Right of existing Roots
	IF @NewParentID = -1
	BEGIN
		SELECT @NewParentRight = MAX(PRight) + 1
		FROM NsmCat
	END
	--Else, place it to the Right of its new siblings-to-be
	ELSE
	BEGIN
		SELECT @NewParentRight = PRight
		FROM NsmCat 
		WHERE CatID = @NewParentID
	END

	--Get new positions for use
	SELECT CatID, PLeft + @NewParentRight - @SubtreeOldLeft AS PLeft, PRight + @NewParentRight - @SubtreeOldLeft AS PRight
	INTO #NsmCatMove
	FROM NsmCat
	WHERE CatID IN (
		SELECT SubCat.CatID
		FROM NsmCat Cat
		JOIN NsmCat SubCat
				ON SubCat.PLeft BETWEEN Cat.PLeft AND Cat.PRight
		WHERE Cat.CatID = @CatID
	)

	--Make gap in NsmCat equal to the SubtreeSize
	UPDATE NsmCat
	SET PLeft = CASE WHEN PLeft > @NewParentRight THEN PLeft + @SubtreeSize ELSE PLeft END,
		PRight = CASE WHEN PRight >= @NewParentRight THEN PRight + @SubtreeSize ELSE PRight END
	WHERE PRight >= @NewParentRight

	--Update Subtree positions to new ones
	UPDATE NsmCat
	SET PLeft = #NsmCatMove.PLeft, PRight = #NsmCatMove.PRight
	FROM NsmCat
	JOIN #NsmCatMove
			ON NsmCat.CatID = #NsmCatMove.CatID

	--Maintain the Adjacency-List part (set ParentID)
	UPDATE NsmCat
	SET ParentID = @NewParentID
	WHERE CatID = @CatID

	--Close gaps, i.e. after the Subtree is gone from its old Parent, said old parent node has no children;
	--while nodes to the right & above now have inflated values, except where they include the newly moved subtree.
	UPDATE NsmCat
	SET PLeft = CASE WHEN PLeft > @SubtreeOldRight THEN PLeft - @SubtreeSize ELSE PLeft END,
		PRight = CASE WHEN PRight >= @SubtreeOldRight THEN PRight - @SubtreeSize ELSE PRight END
	WHERE PRight >= @SubtreeOldRight
END
GO
