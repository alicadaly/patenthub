/****** Script for SelectTopNRows command from SSMS  ******/
/*专利家族信息,
               技术领域：Y02E  10/723',
               国别范围：以美国、欧盟检索，扩展至家族
			   时间2000——2010年
			   */
USE WindEnergy
GO

CREATE TABLE [Attribute](
    [appln_id][int] NOT NULL,
	[appln_auth][nvarchar](2) NOT NULL,
    [docdb_family_id] [int] NULL,
	[YR_PUB] [smallint] NULL,
	[YR_PRI] [smallint] NULL,
	[SQ_APLS] [smallint] NULL,
	[CA_GRANT] [tinyint] NULL,
	[REGION] [nvarchar](2) NOT NULL DEFAULT ('0'),
	[SQ_SCOPE] [nvarchar](4) NOT NULL DEFAULT ('0'),
	[LN_FAMSIZE][smallint] NULL,
    [CA_NPL] [float] NOT NULL DEFAULT ('0'),
CONSTRAINT [PK_Appln_id] PRIMARY KEY CLUSTERED
([Appln_id] ASC))


INSERT INTO [Attribute] (A.docdb_family_id,A.appln_id,A.appln_auth,A.YR_PUB,A.YR_PRI,A.SQ_APLS,A.CA_GRANT,A.LN_FAMSIZE)
SELECT  A.[docdb_family_id] ,
        A.[appln_id],
		A.[appln_auth],
	    A.[publn_earliest_year],
		A.[prior_earliest_year],
	    ROUND(SQRT(A.[nb_applicants]),0) AS SQ_APLS,
	    A.[granted],	  
	    ROUND(LOG(A.[docdb_family_size]+1),0) AS LN_FAMSIZE
FROM [WindEnergy].[dbo].[tls201_appln]A
WHERE A.appln_id IN (SELECT Min(C.appln_id) 
                          FROM [WindEnergy].[dbo].[tls224_appln_cpc] B
                          JOIN [WindEnergy].[dbo].[tls201_appln]C ON B.appln_id=C.appln_id
                          WHERE [cpc_class_symbol]= 'Y02E  10/723' AND C.appln_auth IN ('US','EP') AND C.appln_filing_year BETWEEN 2000 AND 2010 
                          GROUP BY docdb_family_id)
--



UPDATE [Attribute]
SET REGION = E.REGION
FROM [Attribute] F
JOIN  
(
SELECT D.docdb_family_id, COUNT(D.docdb_family_id) AS REGION
FROM 
(SELECT DISTINCT A.appln_auth,B.docdb_family_id,B.appln_id
   FROM [WindEnergy].[dbo].[tls201_appln] A
   JOIN [WindEnergy].[dbo].[Attribute] B ON B.docdb_family_id=A.docdb_family_id
   WHERE A.appln_auth IN ('US','EP')
   )D
   GROUP BY D.docdb_family_id)E ON E.docdb_family_id=F.docdb_family_id



UPDATE [Attribute]
SET SQ_SCOPE = ROUND(SQRT(B.Patent_Scope),0)
FROM [Attribute] A
INNER JOIN (SELECT appln_id, COUNT(DISTINCT LEFT([ipc_class_symbol], 4)) AS Patent_scope
                 FROM [WindEnergy].[dbo].[tls209_appln_ipc]
                 GROUP BY Appln_id) B ON A.appln_id = B.appln_id
                 
/*更新后向引文
UPDATE [Attribute]
SET LN_REFS = ROUND(LOG(B.Cited+1),0)
FROM [Attribute]  A
INNER JOIN
     (SELECT B.appln_id, COUNT(distinct D.cited_pat_publn_id) AS Cited
          FROM [WindEnergy].[dbo].[tls201_appln] B 
          LEFT JOIN [WindEnergy].[dbo].[tls211_pat_publn] C ON B.appln_id=C.appln_id
          INNER JOIN [WindEnergy].[dbo].[tls212_citation] D ON C.pat_publn_id=D.pat_publn_id
		  WHERE D.pat_citn_seq_nr > 0 
		  GROUP BY B.appln_id
		  ) B 
ON A.appln_id=B.appln_id*/

--更新非专利引文

UPDATE [Attribute]
SET CA_NPL = NPL_Total
FROM [Attribute] A
INNER JOIN
     (SELECT B.appln_id, COUNT(distinct D.npl_publn_id) AS NPL_Total
          FROM [WindEnergy].[dbo].[tls201_appln] B 
          LEFT JOIN [WindEnergy].[dbo].[tls211_pat_publn] C ON B.appln_id=C.appln_id
          INNER JOIN [WindEnergy].[dbo].[tls212_citation] D ON C.pat_publn_id=D.pat_publn_id
		  WHERE D.npl_citn_seq_nr > 0 
		  GROUP BY B.appln_id
		  ) B 
ON A.appln_id=B.appln_id

  
--专利家族引文引用表
SELECT [citing_docdb_family_id],[cited_docdb_family_id]
  FROM [WindEnergy].[dbo].[docdb_family_citation]
  WHERE 
        [cited_docdb_family_id] IN 
  (SELECT docdb_family_id
  FROM Attribute )
  AND  
       [citing_docdb_family_id] IN 
  (SELECT docdb_family_id
  FROM Attribute)

  
  
--申请人关系
 
  SELECT A.[docdb_family_id],C.[doc_std_name_id_replenished]
    FROM [WindEnergy].[dbo].[Attribute] A
    JOIN [WindEnergy].[dbo].[tls207_pers_appln] B ON A.appln_id=B.appln_id
    JOIN [WindEnergy].[dbo].[tls206_person] C ON C.person_id=B.person_id
-- WHERE B.applt_seq_nr>0 OR B.invt_seq_nr>0
--核心是4列appln_id,person_id,person_ctry_code,doc_std_name_id_replenished

--申请人地域关系
SELECT DISTINCT A.[docdb_family_id]
      ,C.[person_ctry_code]
    FROM [WindEnergy].[dbo].[Attribute] A
    JOIN [WindEnergy].[dbo].[tls207_pers_appln] B ON A.appln_id=B.appln_id
    JOIN [WindEnergy].[dbo].[tls206_person] C ON C.person_id=B.person_id
    WHERE C.person_ctry_code<>''


--专利分类号关系
SELECT DISTINCT B.docdb_family_id
      ,REPLACE(LEFT(ipc_class_symbol,13),' ','') AS ipc_class
  FROM [WindEnergy].[dbo].[tls209_appln_ipc] A
  JOIN [WindEnergy].[dbo].[Attribute] B ON A.appln_id=B.appln_id
  
--技术领域关系
SELECT B.docdb_family_id
      ,[techn_field]
  FROM [WindEnergy].[dbo].[tls209_appln_ipc] A
  JOIN [WindEnergy].[dbo].[Attribute] B ON A.appln_id=B.appln_id

