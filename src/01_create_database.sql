-- Fase 1: create the project database.
IF DB_ID(N'maven_fuzzy_factory') IS NULL
BEGIN
    CREATE DATABASE maven_fuzzy_factory;
END
GO
