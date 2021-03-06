USE [LeafDB]
GO

/*
 * Update version.
 */
IF EXISTS (SELECT 1 FROM [ref].[Version])
    UPDATE ref.Version
    SET [Version] = '3.5.0'
ELSE 
    INSERT INTO ref.[Version] (Lock, Version)
    SELECT 'X', '3.5.0'

/*
 * app.Import
 */
IF OBJECT_ID('app.Import', 'U') IS NOT NULL 
	DROP TABLE app.Import;
GO

CREATE TABLE app.Import
(
    [Id] NVARCHAR(200) NOT NULL,
    [ImportMetadataId] UNIQUEIDENTIFIER NOT NULL,
    [PersonId] NVARCHAR(200) NOT NULL,
    [SourcePersonId] NVARCHAR(200) NOT NULL,
	[SourceModifier] NVARCHAR(100) NULL,
    [SourceValue] NVARCHAR(100) NOT NULL,
    [ValueString] NVARCHAR(100) NULL,
    [ValueNumber] DECIMAL(18,3) NULL,
    [ValueDate] DATETIME NULL,
    
    CONSTRAINT [PK_Import_1] PRIMARY KEY CLUSTERED 
(
    [Id] ASC,
    [ImportMetadataId] ASC,
    [PersonId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

/*
 * app.ImportPatientMappingQuery
 */
IF OBJECT_ID('app.ImportPatientMappingQuery', 'U') IS NOT NULL 
	DROP TABLE app.ImportPatientMappingQuery;
GO
CREATE TABLE app.ImportPatientMappingQuery(
	[Lock] [char](1) NOT NULL,
	[SqlStatement] [nvarchar](4000) NOT NULL,
	[SqlFieldSourceId] [nvarchar](100) NOT NULL,
	[LastChanged] [datetime] NOT NULL,
	[ChangedBy] [nvarchar](200) NOT NULL,
 CONSTRAINT [PK_ImportPatientMappingQuery] PRIMARY KEY CLUSTERED 
(
	[Lock] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [app].[ImportPatientMappingQuery] ADD  CONSTRAINT [DF_ImportPatientMappingQuery_Lock]  DEFAULT ('X') FOR [Lock]
GO
ALTER TABLE [app].[ImportPatientMappingQuery]  WITH CHECK ADD  CONSTRAINT [CK_ImportPatientMappingQuery_1] CHECK  (([Lock]='X'))
GO
ALTER TABLE [app].[ImportPatientMappingQuery] CHECK CONSTRAINT [CK_ImportPatientMappingQuery_1]
GO

/*
 * auth.ImportMetadataConstraint
 */
IF OBJECT_ID('auth.ImportMetadataConstraint', 'U') IS NOT NULL 
	DROP TABLE auth.ImportMetadataConstraint;
GO

CREATE TABLE [auth].[ImportMetadataConstraint](
	[ImportMetadataId] [uniqueidentifier] NOT NULL,
	[ConstraintId] [int] NOT NULL,
	[ConstraintValue] [nvarchar](1000) NOT NULL,
 CONSTRAINT [PK_ImportMetadataConstraint] PRIMARY KEY CLUSTERED 
(
	[ImportMetadataId] ASC,
	[ConstraintId] ASC,
	[ConstraintValue] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

/* 
 * app.ImportMetadata
 */
IF OBJECT_ID('app.ImportMetadata', 'U') IS NOT NULL 
	DROP TABLE app.ImportMetadata;
GO

CREATE TABLE app.ImportMetadata
(
    [Id] UNIQUEIDENTIFIER NOT NULL,
	[SourceId] NVARCHAR(200) NOT NULL,
    [Structure] NVARCHAR(MAX) NOT NULL,
    [Type] INT NOT NULL,
    Created DATETIME NOT NULL,
    CreatedBy NVARCHAR(200) NOT NULL,
    Updated DATETIME NOT NULL,
    UpdatedBy NVARCHAR(200) NOT NULL,

    CONSTRAINT [PK_ImportMetadata_1] PRIMARY KEY CLUSTERED 
(
    [Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

/* 
 * ref.ImportType
 */
IF OBJECT_ID('ref.ImportType', 'U') IS NOT NULL 
	DROP TABLE ref.ImportType;
GO

CREATE TABLE ref.ImportType
(
    Id INT NOT NULL,
    Variant NVARCHAR(100) NOT NULL
    CONSTRAINT [PK_Import_1] PRIMARY KEY CLUSTERED 
(
    [Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

INSERT INTO ref.ImportType (Id, Variant)
VALUES (1, 'REDCap Project'), (2, 'MRN')
GO

ALTER TABLE [app].[ImportMetadata] ADD  CONSTRAINT [DF_Id]  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [app].[ImportMetadata]  WITH CHECK ADD CONSTRAINT [FK_ImportMetadata_Type] FOREIGN KEY([Type]) REFERENCES [ref].[ImportType] ([Id])
GO
ALTER TABLE [app].[ImportMetadata] CHECK CONSTRAINT [FK_ImportMetadata_Type]
GO

ALTER TABLE [auth].[ImportMetadataConstraint]  WITH CHECK ADD  CONSTRAINT [FK_ImportMetadataConstraint_ConstraintId] FOREIGN KEY([ConstraintId])
REFERENCES [auth].[Constraint] ([Id])
GO

ALTER TABLE [auth].[ImportMetadataConstraint] CHECK CONSTRAINT [FK_ImportMetadataConstraint_ConstraintId]
GO

ALTER TABLE [auth].[ImportMetadataConstraint]  WITH CHECK ADD  CONSTRAINT [FK_ImportMetadataConstraint_ImportMetadataId] FOREIGN KEY([ImportMetadataId])
REFERENCES [app].[ImportMetadata] ([Id])
GO

ALTER TABLE [auth].[ImportMetadataConstraint] CHECK CONSTRAINT [FK_ImportMetadataConstraint_ImportMetadataId]
GO

ALTER TABLE [app].[Import]  WITH CHECK ADD  CONSTRAINT [FK_ImportConstraint_ImportMetadataId] FOREIGN KEY([ImportMetadataId])
REFERENCES [app].[ImportMetadata] ([Id])
GO

ALTER TABLE [app].[Import] CHECK CONSTRAINT [FK_ImportConstraint_ImportMetadataId]
GO

/*
 * fn_UserIsAuthorizedForImportMetadataById.
 */
IF OBJECT_ID('auth.fn_UserIsAuthorizedForImportMetadataById', 'FN') IS NOT NULL 
	DROP FUNCTION [auth].[fn_UserIsAuthorizedForImportMetadataById];
GO

-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/10/14
-- Description: Performs a security check on the requested ImportMetadataId.
-- =======================================
CREATE FUNCTION [auth].[fn_UserIsAuthorizedForImportMetadataById]
(
    @user [auth].[User],
    @groups [auth].[GroupMembership] READONLY,
    @id UNIQUEIDENTIFIER,
    @admin bit
)
RETURNS bit
AS
BEGIN
    -- Get the constraints for user and groups, make sure the constraint is satisfied.
    DECLARE @authorizations auth.Authorizations;

    INSERT INTO @authorizations (ConstraintId, ConstraintValue)
    SELECT
        IM.ConstraintId,
        IM.ConstraintValue
    FROM
        auth.ImportMetadataConstraint AS IM
    WHERE
        IM.ImportMetadataId = @id;

    RETURN auth.fn_UserIsAuthorized(@user, @groups, @authorizations, @admin);

END
GO

/*
 * ImportDataTable Table Type.
 */
IF OBJECT_ID('app.sp_ImportData', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_ImportData];
GO
IF TYPE_ID('app.ImportDataTable') IS NOT NULL 
	DROP TYPE [app].[ImportDataTable];
GO

CREATE TYPE [app].[ImportDataTable] AS TABLE(
	Id NVARCHAR(200) NOT NULL,
	ImportMetadataId UNIQUEIDENTIFIER NOT NULL,
	PersonId NVARCHAR(100) NOT NULL,
	SourcePersonId NVARCHAR(100) NOT NULL,
	SourceValue NVARCHAR(100),
	[SourceModifier] [nvarchar](100) NULL,
	ValueString NVARCHAR(100),
	ValueNumber DECIMAL(18,3),
	ValueDate DATETIME
)
GO

/*
 * [app].[sp_GetImportMetadataBySourceId]
 */
IF OBJECT_ID('app.sp_GetImportPatientMappingQuery', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetImportPatientMappingQuery];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/10/29
-- Description: Fetch the app.ImportPatientMappingQuery record.
-- =======================================
CREATE PROCEDURE [app].[sp_GetImportPatientMappingQuery]
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        SqlStatement,
        SqlFieldSourceId
    FROM app.ImportPatientMappingQuery;
END
GO


/*
 * [app].[sp_GetImportMetadataBySourceId]
 */
IF OBJECT_ID('app.sp_GetImportMetadata', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetImportMetadata];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Retrieves all Import Metadata depending on user and groups.
-- =======================================
CREATE PROCEDURE [app].[sp_GetImportMetadata]
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	DECLARE @requested app.ResourceIdTable;

	INSERT INTO @requested
	SELECT Id
	FROM app.ImportMetadata;

	DECLARE @ids TABLE (Id uniqueidentifier)

	IF (@admin = 1)
    BEGIN;
        -- user is an admin, load them all
        INSERT INTO @ids
        SELECT IM.Id
        FROM app.ImportMetadata AS IM
    END;
    ELSE
    BEGIN;
        -- user is not an admin, assess their privilege
        INSERT INTO @ids (Id)
        SELECT
            IM.Id
        FROM app.ImportMetadata AS IM
        WHERE EXISTS (
            SELECT 1
            FROM auth.ImportMetadataConstraint
            WHERE ImportMetadataId = IM.Id AND
            ConstraintId = 1 AND
            ConstraintValue = @user
        )
        OR EXISTS (
            SELECT 1
            FROM auth.ImportMetadataConstraint
            WHERE ImportMetadataId = IM.Id AND
            ConstraintId = 2 AND
            ConstraintValue in (SELECT [Group] FROM @groups)
        )
        OR NOT EXISTS (
            SELECT 1
            FROM auth.ImportMetadataConstraint
            WHERE ImportMetadataId = IM.Id
        );
    END;

	SELECT 
		Id
	  , SourceId
	  , Structure
	  , [Type]
	  , Created
	  , Updated
	FROM app.ImportMetadata AS IM
	WHERE EXISTS (SELECT 1 FROM @ids AS I WHERE I.Id = IM.Id)

	SELECT
		ImportMetadataId
	  , ConstraintId
	  , ConstraintValue
	FROM auth.ImportMetadataConstraint AS IMC
	WHERE EXISTS (SELECT 1 FROM @ids AS I WHERE I.Id = IMC.ImportMetadataId);

END
GO

/*
 * [app].[sp_CreateImportMetadata]
 */
IF OBJECT_ID('app.sp_CreateImportMetadata', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_CreateImportMetadata];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Creates an Import Metadata record.
-- =======================================
CREATE PROCEDURE [app].[sp_CreateImportMetadata]
    @user auth.[User],
	@constraints auth.ResourceConstraintTable READONLY,
	@sourceId nvarchar(100),
	@type int,
	@structure nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON

	IF (NOT EXISTS (SELECT 1 FROM ref.ImportType AS IT WHERE @type = IT.Id))
    BEGIN;
        THROW 70404, N'ImportType does not exist.', 1;
    END;

	IF (app.fn_NullOrWhitespace(@sourceId) = 1)
        THROW 70400, N'SourceId is required.', 1;

	IF (app.fn_NullOrWhitespace(@structure) = 1)
        THROW 70400, N'Structure is required.', 1;

	DECLARE @created TABLE (Id uniqueidentifier, SourceId nvarchar(100), Structure nvarchar(max), [Type] int, Created datetime, Updated datetime);
	DECLARE @cons TABLE (ImportMetadataId uniqueidentifier, ConstraintId int, ConstraintValue nvarchar(100));

	-- INSERT metadata row
	INSERT INTO app.ImportMetadata (SourceId, [Type], Structure, Created, CreatedBy, Updated, UpdatedBy)
	OUTPUT inserted.Id, inserted.SourceId, inserted.Structure, inserted.[Type], inserted.Created, inserted.Updated INTO @created
	VALUES (@sourceId, @type, @structure, GETDATE(), @user, GETDATE(), @user);

	DECLARE @id uniqueidentifier = (SELECT TOP 1 Id FROM @created);

	-- INSERT contraints
	INSERT INTO auth.ImportMetadataConstraint (ImportMetadataId, ConstraintId, ConstraintValue)
	OUTPUT inserted.ImportMetadataId, inserted.ConstraintId, inserted.ConstraintValue INTO @cons
	SELECT
		ImportMetadataId = @id
	  , C.ConstraintId
	  , C.ConstraintValue
	FROM @constraints AS C;

	SELECT * FROM @created;
	SELECT * FROM @cons;

END
GO

/*
 * [app].[sp_UpdateImportMetadata]
 */
IF OBJECT_ID('app.sp_UpdateImportMetadata', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_UpdateImportMetadata];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Updates an Import Metadata record.
-- =======================================
CREATE PROCEDURE [app].[sp_UpdateImportMetadata]
	@id uniqueidentifier,
	@sourceId nvarchar(100),
	@type int,
	@structure nvarchar(max),
	@constraints auth.ResourceConstraintTable READONLY,
    @user auth.[User],
	@groups auth.GroupMembership READONLY,
	@admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	IF (NOT EXISTS (SELECT 1 FROM ref.ImportType AS IT WHERE @type = IT.Id))
    BEGIN;
        THROW 70404, N'ImportType does not exist.', 1;
    END;

	IF (app.fn_NullOrWhitespace(@sourceId) = 1)
        THROW 70400, N'SourceId is required.', 1;

	IF (app.fn_NullOrWhitespace(@structure) = 1)
        THROW 70400, N'Structure is required.', 1;

	DECLARE @authorized BIT = [auth].[fn_UserIsAuthorizedForImportMetadataById](@user, @groups, @id, @admin)

	IF @authorized = 0
	BEGIN;
		DECLARE @403msg1 nvarchar(400) = @user + N' is not allowed to to alter import ' + CONVERT(NVARCHAR(100),@id);
        THROW 70403, @403msg1, 1;
	END;

	DECLARE @updated TABLE (Id uniqueidentifier, SourceId nvarchar(100), Structure nvarchar(max), [Type] int, Created datetime, Updated datetime);
	DECLARE @cons TABLE (ImportMetadataId uniqueidentifier, ConstraintId int, ConstraintValue nvarchar(100))

	-- INSERT metadata row
	UPDATE TOP (1) app.ImportMetadata 
	SET 
		SourceId = @sourceId
	  , [Type] = @type
	  , Structure = @structure
	  , Updated = GETDATE()
	  , UpdatedBy = @user
	OUTPUT inserted.Id, inserted.SourceId, inserted.Structure, inserted.[Type], inserted.Created, inserted.Updated INTO @updated
	WHERE Id = @id;

	-- DELETE any previous constraints
	DELETE auth.ImportMetadataConstraint
	WHERE ImportMetadataId = @id;

	-- INSERT contraints
	INSERT INTO auth.ImportMetadataConstraint (ImportMetadataId, ConstraintId, ConstraintValue)
	OUTPUT inserted.ImportMetadataId, inserted.ConstraintId, inserted.ConstraintValue INTO @cons
	SELECT
		ImportMetadataId = @id
	  , C.ConstraintId
	  , C.ConstraintValue
	FROM @constraints AS C;

	SELECT * FROM @updated;
	SELECT * FROM @cons;

END
GO

/*
 * [app].[sp_DeleteImportMetadata]
 */
IF OBJECT_ID('app.sp_DeleteImportMetadata', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_DeleteImportMetadata];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Deletes an Import Metadata record.
-- =======================================
CREATE PROCEDURE [app].[sp_DeleteImportMetadata]
	@id uniqueidentifier,
    @user auth.[User],
	@groups auth.GroupMembership READONLY,
	@admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	IF (NOT EXISTS (SELECT 1 FROM app.ImportMetadata AS IT WHERE @id = IT.Id))
    BEGIN;
        THROW 70404, N'ImportMetadata does not exist.', 1;
    END;

	DECLARE @authorized BIT = [auth].[fn_UserIsAuthorizedForImportMetadataById](@user, @groups, @id, @admin)

	IF @authorized = 0
	BEGIN;
		DECLARE @403msg1 nvarchar(400) = @user + N' is not allowed to to delete import ' + CONVERT(NVARCHAR(100),@id);
        THROW 70403, @403msg1, 1;
	END;

	DECLARE @deleted TABLE (Id uniqueidentifier, SourceId nvarchar(100), Structure nvarchar(max), [Type] int);
	DECLARE @cons TABLE (ImportMetadataId uniqueidentifier, ConstraintId int, ConstraintValue nvarchar(100))

	-- DELETE any constraints
	DELETE auth.ImportMetadataConstraint
	OUTPUT deleted.ImportMetadataId, deleted.ConstraintId, deleted.ConstraintValue INTO @cons
	WHERE ImportMetadataId = @id;

	-- DELETE any imported data
	DELETE app.Import
	WHERE ImportMetadataId = @id

	-- DELETE metadata
	DELETE app.ImportMetadata
	OUTPUT deleted.Id, deleted.SourceId, deleted.Structure, deleted.[Type] INTO @deleted
	WHERE Id = @id;

	SELECT * FROM @deleted;
	SELECT * FROM @cons;

END
GO

/*
 * [app].[sp_ImportData]
 */
IF OBJECT_ID('app.sp_ImportData', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_ImportData];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Adds import records tied to a metadata record.
-- =======================================
CREATE PROCEDURE [app].[sp_ImportData]
	@id uniqueidentifier,
	@data [app].[ImportDataTable] READONLY,
    @user auth.[User],
	@groups auth.GroupMembership READONLY,
	@admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	IF (NOT EXISTS (SELECT 1 FROM app.ImportMetadata AS IT WHERE @id = IT.Id))
    BEGIN;
        THROW 70404, N'ImportMetadata does not exist.', 1;
    END;

	DECLARE @authorized BIT = [auth].[fn_UserIsAuthorizedForImportMetadataById](@user, @groups, @id, @admin)

	IF @authorized = 0
	BEGIN;
		DECLARE @403msg1 nvarchar(400) = @user + N' is not allowed to to import data for ' + CONVERT(NVARCHAR(100),@id);
        THROW 70403, @403msg1, 1;
	END;

	DECLARE @changed INT = 0;

	-- Check for UPDATEs
	UPDATE app.Import
	SET
		PersonId = D.PersonId
	  , SourcePersonId = D.SourcePersonId
	  , SourceValue = D.SourceValue
	  , SourceModifier = D.SourceModifier
	  , ValueString = D.ValueString
	  , ValueNumber = D.ValueNumber
	  , ValueDate = D.ValueDate
	FROM @data AS D
		 INNER JOIN app.Import AS I
			ON I.Id = D.Id 
			   AND I.PersonId = D.PersonId
			   AND I.ImportMetadataId = D.ImportMetadataId
			   AND I.ImportMetadataId = @id

	SET @changed += @@ROWCOUNT
	
	-- INSERT the remainder
	INSERT INTO app.Import(Id, ImportMetadataId, PersonId, SourcePersonId, SourceValue, SourceModifier, ValueString, ValueNumber, ValueDate)
	SELECT
		D.Id
	  , ImportMetadataId = @id
	  , D.PersonId
	  , D.SourcePersonId
	  , D.SourceValue
	  , D.SourceModifier
	  , D.ValueString
	  , D.ValueNumber
	  , D.ValueDate
	FROM @data AS D
	WHERE NOT EXISTS (SELECT 1 
					  FROM app.Import AS I 
					  WHERE I.Id = D.Id 
						    AND I.PersonId = D.PersonId
						    AND I.ImportMetadataId = D.ImportMetadataId
						    AND I.ImportMetadataId = @id)

	SELECT Changed = @changed + @@ROWCOUNT

END
GO

/*
 * [app].[sp_GetImportData]
 */
IF OBJECT_ID('app.sp_GetImportData', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetImportData];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Gets all imported records for a given metadata.
-- =======================================
CREATE PROCEDURE [app].[sp_GetImportData]
	@id uniqueidentifier,
    @user auth.[User],
	@groups auth.GroupMembership READONLY,
	@admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	IF (NOT EXISTS (SELECT 1 FROM app.ImportMetadata AS IT WHERE @id = IT.Id))
    BEGIN;
        THROW 70404, N'ImportMetadata does not exist.', 1;
    END;

	DECLARE @authorized BIT = [auth].[fn_UserIsAuthorizedForImportMetadataById](@user, @groups, @id, @admin)

	IF @authorized = 0
	BEGIN;
		DECLARE @403msg1 nvarchar(400) = @user + N' is not allowed to access import ' + CONVERT(NVARCHAR(100),@id);
        THROW 70403, @403msg1, 1;
	END;

	DECLARE @changed INT = 0;

	SELECT
		I.Id
	  , I.ImportMetadataId
	  , I.PersonId
	  , I.SourcePersonId
	  , I.SourceValue
	  , I.ValueString
	  , I.ValueNumber
	  , I.ValueDate
	FROM app.Import AS I
	WHERE I.ImportMetadataId = @id

END
GO

/*
 * [app].[sp_GetImportMetadataById]
 */
IF OBJECT_ID('app.sp_GetImportMetadataById', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetImportMetadataById];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Retrieves Import Metadata by Id.
-- =======================================
CREATE PROCEDURE [app].[sp_GetImportMetadataById]
	@id uniqueidentifier,
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	DECLARE @authorized BIT = [auth].[fn_UserIsAuthorizedForImportMetadataById](@user, @groups, @id, @admin)

	IF @authorized = 0
	BEGIN;
		DECLARE @403msg1 nvarchar(400) = @user + N' is not allowed to to use import ' + CONVERT(NVARCHAR(100),@id);
        THROW 70403, @403msg1, 1;
	END;

	SELECT 
		Id
	  , SourceId
	  , Structure
	  , [Type]
	  , Created
	  , Updated
	FROM app.ImportMetadata AS IM
	WHERE IM.Id = @id

	SELECT
		ImportMetadataId
	  , ConstraintId
	  , ConstraintValue
	FROM auth.ImportMetadataConstraint AS IMC
	WHERE IMC.ImportMetadataId = @id

END
GO

/*
 * [app].[sp_GetImportMetadataBySourceId]
 */
IF OBJECT_ID('app.sp_GetImportMetadataBySourceId', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetImportMetadataBySourceId];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/30
-- Description: Retrieves Import Metadata by SourceId.
-- =======================================
CREATE PROCEDURE [app].[sp_GetImportMetadataBySourceId]
	@sourceId nvarchar(100),
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	DECLARE @id uniqueidentifier = (SELECT TOP 1 Id from app.ImportMetadata WHERE SourceId = @sourceId)

	EXEC app.sp_GetImportMetadataById @id, @user, @groups, @admin

END
GO

/*
 * [app].[sp_GetPreflightImportsByIds]
 */
IF OBJECT_ID('app.sp_GetPreflightImportsByIds', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetPreflightImportsByIds];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/10/21
-- Description: Retrieves preflight import Ids by Id.
-- =======================================
CREATE PROCEDURE [app].[sp_GetPreflightImportsByIds]
    @ids app.ResourceIdTable READONLY,
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	DECLARE @authorized TABLE (Id uniqueIdentifier)
	DECLARE @results TABLE (Id uniqueidentifier, IsPresent bit, IsAuthorized bit)
	INSERT INTO @results (Id, IsPresent, IsAuthorized)
	SELECT 
		Id
	  , IsPresent = CASE WHEN EXISTS (SELECT 1 FROM app.ImportMetadata AS IM WHERE IM.Id = IDS.Id) THEN 1 ELSE 0 END
	  , IsAuthorized = 0
	FROM @ids AS IDS

	IF (@admin = 1)
    BEGIN;
        -- user is an admin, load all
		INSERT INTO @authorized (Id)
        SELECT IM.Id
        FROM app.ImportMetadata AS IM
		WHERE EXISTS (SELECT 1 FROM @ids AS IDS WHERE IM.ID = IDS.Id)
    END;
    ELSE
    BEGIN;
        -- user is not an admin, assess their privilege
		INSERT INTO @authorized (Id)
        SELECT IM.Id
        FROM app.ImportMetadata AS IM
        WHERE EXISTS (SELECT 1 FROM @ids AS IDS WHERE IM.ID = IDS.Id)
		AND
		(
			EXISTS (
				SELECT 1
				FROM auth.ImportMetadataConstraint AS IMC
				WHERE IMC.ImportMetadataId = IM.Id AND
				ConstraintId = 1 AND
				ConstraintValue = @user
			)
			OR EXISTS (
				SELECT 1
				FROM auth.ImportMetadataConstraint AS IMC
				WHERE IMC.ImportMetadataId = IM.Id AND
				ConstraintId = 2 AND
				ConstraintValue in (SELECT [Group] FROM @groups)
			)
			OR NOT EXISTS (
				SELECT 1
				FROM auth.ImportMetadataConstraint AS IMC
				WHERE IMC.ImportMetadataId = IM.Id
			)
		);
    END;

	UPDATE @results
	SET IsAuthorized = 1
	FROM @results AS R
	WHERE EXISTS (SELECT 1 FROM @authorized AS A WHERE R.Id = A.Id)

	SELECT *
	FROM @results

END
GO

/*
 * [app].[sp_GetPreflightImportsByUIds]
 */
IF OBJECT_ID('app.sp_GetPreflightImportsByUIds', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetPreflightImportsByUIds];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/10/21
-- Description: Retrieves preflight import Ids by UId.
-- =======================================
CREATE PROCEDURE [app].[sp_GetPreflightImportsByUIds]
    @uids app.ResourceUniversalIdTable READONLY,
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

	-- Imports cannot be accessed by UID, return nothing.
	SELECT 
		Id = CAST(NULL AS uniqueidentifier)
	  , IsPresent = CAST(0 AS BIT)
	  , IsAuthorized = CAST(0 AS BIT)

END
GO

/*
 * [app].[sp_GetPreflightResourcesByIds]
 */
IF OBJECT_ID('app.sp_GetPreflightResourcesByIds', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetPreflightResourcesByIds];
GO
-- =======================================
-- Author:      Cliff Spital
-- Create date: 2019/2/4
-- Description: Performs a preflight resource check by Ids.
-- =======================================
CREATE PROCEDURE [app].[sp_GetPreflightResourcesByIds]
    @qids app.ResourceIdTable READONLY,
    @cids app.ResourceIdTable READONLY,
	@iids app.ResourceIdTable READONLY,
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @sessionType auth.SessionType,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

    exec app.sp_GetPreflightQueriesByIds @qids, @user, @groups, @admin = @admin;

    exec app.sp_GetPreflightConceptsByIds @cids, @user, @groups, @admin = @admin;

	exec app.sp_GetPreflightImportsByIds @iids, @user, @groups, @admin = @admin

    exec app.sp_GetPreflightGlobalPanelFilters @sessionType;
END
GO

/*
 * [app].[sp_GetPreflightResourcesByUIds]
 */
IF OBJECT_ID('app.sp_GetPreflightResourcesByUIds', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetPreflightResourcesByUIds];
GO
-- =======================================
-- Author:      Cliff Spital
-- Create date: 2019/2/4
-- Description: Performs a preflight resources check by UIds
-- =======================================
CREATE PROCEDURE [app].[sp_GetPreflightResourcesByUIds]
    @quids app.ResourceUniversalIdTable READONLY,
    @cuids app.ResourceUniversalIdTable READONLY,
	@iuids app.ResourceUniversalIdTable READONLY,
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @sessionType auth.SessionType,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

    exec app.sp_GetPreflightQueriesByUIds @quids, @user, @groups, @admin = @admin;

    exec app.sp_GetPreflightConceptsByUIds @cuids, @user, @groups, @admin = @admin;

	exec app.sp_GetPreflightImportsByUIds @iuids, @user, @groups, @admin = @admin;

    exec app.sp_GetPreflightGlobalPanelFilters @sessionType;
END
GO


