#Requires -Version 7.0
<#
================================================================================
 AI Project Initializer
================================================================================
 Scaffolds a professional AI backend project from an already initialized
 Git repository.

 Version   : 1.0.0
 Language  : PowerShell 7+
 Platform  : Windows

 Usage:
     Run from the repository root (the folder containing .git, .gitignore,
     and README.md):

         ./init.ps1

 Behavior:
     - Safe by default. Idempotent. Never overwrites existing user files.
     - Fails fast on invalid repository state.
     - Generates runnable code only. No placeholder business logic.
================================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

$Script:ScriptVersion = "1.0.0"
$Script:TemplateName = "Quaesitor AI Template"

$Script:RequiredFiles = @(".gitignore", "README.md")
$Script:RequiredGitFolder = ".git"
$Script:OptionalLicenseFile = "LICENSE"
$Script:ProtectedDirectoryName = "backend"

$Script:RequiredGitIgnoreEntries = @(
    ".venv/",
    "venv/",
    ".env",
    "__pycache__/",
    ".pytest_cache/",
    "backend/storage/"
)

$Script:ExitCodeSuccess = 0
$Script:ExitCodeValidationFailure = 1
$Script:ExitCodeRuntimeFailure = 2

# ==============================================================================
# LOGGING
# ==============================================================================

$Script:CreatedDirectories = [System.Collections.Generic.List[string]]::new()
$Script:CreatedFiles = [System.Collections.Generic.List[string]]::new()
$Script:SkippedItems = [System.Collections.Generic.List[string]]::new()
$Script:WarningItems = [System.Collections.Generic.List[string]]::new()

function Write-Banner {
    <#
        Prints the initializer banner to the console.
    #>
    $line = "=" * 60
    Write-Host $line
    Write-Host "AI PROJECT INITIALIZER v$Script:ScriptVersion"
    Write-Host $line
    Write-Host ""
}

function Write-SectionHeader {
    <#
        Prints a section header to the console.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host $Title
}

function Write-Success {
    <#
        Prints a single success line to the console, prefixed with a checkmark.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "  OK  $Message"
}

function Add-InitializerWarning {
    <#
        Records a warning and prints it immediately.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Script:WarningItems.Add($Message)
    Write-Host "  WARN  $Message"
}

# ==============================================================================
# VALIDATION
# ==============================================================================

function Test-RepositoryRoot {
    <#
        Validates that the script is being run from a proper repository root.
        Throws a terminating error if validation fails.
    #>

    $currentDirectoryName = Split-Path -Path (Get-Location).Path -Leaf

    if ($currentDirectoryName -eq $Script:ProtectedDirectoryName) {
        throw "Refusing to run inside '$Script:ProtectedDirectoryName/'. " +
        "Reason: this script scaffolds a project from the repository root, not from within backend/. " +
        "Fix: navigate to the repository root (the parent of backend/) and run the script again."
    }

    if (-not (Test-Path -Path $Script:RequiredGitFolder -PathType Container)) {
        throw "Missing '$Script:RequiredGitFolder' directory. " +
        "Reason: this does not appear to be an initialized Git repository. " +
        "Fix: run 'git init' in this directory before running the initializer."
    }

    foreach ($requiredFile in $Script:RequiredFiles) {
        if (-not (Test-Path -Path $requiredFile -PathType Leaf)) {
            throw "Missing required file '$requiredFile'. " +
            "Reason: the initializer requires an already-established repository with a README and .gitignore. " +
            "Fix: create '$requiredFile' in the repository root before running the initializer."
        }
    }

    if (-not (Test-Path -Path $Script:OptionalLicenseFile -PathType Leaf)) {
        Add-InitializerWarning "No LICENSE file found. Consider adding one before publishing this repository."
    }

    Write-Success "Repository validation passed"
}

function Get-ProjectIdentity {
    <#
        Derives ProjectName and ProjectSlug from the current repository
        directory name. Names are never hardcoded.
    #>

    $projectName = Split-Path -Path (Get-Location).Path -Leaf
    $projectSlug = $projectName.ToLowerInvariant()

    return [PSCustomObject]@{
        ProjectName = $projectName
        ProjectSlug = $projectSlug
    }
}

# ==============================================================================
# FILESYSTEM ENGINE
# ==============================================================================

function New-ProjectItem {
    <#
        Single reusable function for creating directories and files.
        Automatically creates parent directories. Never overwrites an
        existing file or directory. Logs every operation.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Directory", "File")]
        [string]$ItemType,

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Content = ""
    )

    if ($ItemType -eq "Directory") {
        if (Test-Path -Path $Path -PathType Container) {
            $Script:SkippedItems.Add("Directory: $Path")
            return
        }

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        $Script:CreatedDirectories.Add($Path)
        Write-Success $Path
        return
    }

    # ItemType -eq "File"
    if (Test-Path -Path $Path -PathType Leaf) {
        $Script:SkippedItems.Add("File: $Path")
        return
    }

    $parentDirectory = Split-Path -Path $Path -Parent
    if ($parentDirectory -and -not (Test-Path -Path $parentDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $parentDirectory -Force | Out-Null
    }

    Set-Content -Path $Path -Value $Content -Encoding utf8NoBOM -NoNewline
    $Script:CreatedFiles.Add($Path)
    Write-Success $Path
}

# ==============================================================================
# GITIGNORE MANAGER
# ==============================================================================

function Update-GitIgnore {
    <#
        Reads .gitignore once, appends only missing required entries,
        and writes .gitignore once. Never duplicates entries. Never
        overwrites existing content.
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$RequiredEntries
    )

    $existingLines = @(Get-Content -Path ".gitignore" -Encoding utf8)
    $existingTrimmed = $existingLines | ForEach-Object { $_.Trim() }

    $entriesToAdd = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $RequiredEntries) {
        if ($existingTrimmed -notcontains $entry) {
            $entriesToAdd.Add($entry)
        }
    }

    if ($entriesToAdd.Count -eq 0) {
        $Script:SkippedItems.Add("File: .gitignore (no changes needed)")
        return
    }

    $updatedLines = [System.Collections.Generic.List[string]]::new()
    $updatedLines.AddRange([string[]]$existingLines)

    if ($updatedLines.Count -gt 0 -and $updatedLines[$updatedLines.Count - 1].Trim() -ne "") {
        $updatedLines.Add("")
    }

    foreach ($entry in $entriesToAdd) {
        $updatedLines.Add($entry)
        Write-Success "Added `"$entry`" to .gitignore"
    }

    Set-Content -Path ".gitignore" -Value $updatedLines -Encoding utf8NoBOM
}

# ==============================================================================
# FOLDER STRUCTURE ENGINE
# ==============================================================================

function Get-ProjectFolderList {
    <#
        Returns the complete list of directories to be created, relative
        to the repository root.
    #>

    return @(
        ".github",

        "backend",
        "backend/api",
        "backend/agents",
        "backend/rag",
        "backend/prompts",

        "backend/database",
        "backend/database/vector",
        "backend/database/relational",

        "backend/memory",
        "backend/services",
        "backend/schemas",
        "backend/models",

        "backend/core",
        "backend/config",

        "backend/evaluation",
        "backend/scripts",
        "backend/tests",

        "backend/storage",
        "backend/storage/uploads",
        "backend/storage/cache",
        "backend/storage/temp",

        "frontend",
        "docs",
        "data"
    )
}

function Get-PythonPackageInitFileList {
    <#
        Returns the complete list of __init__.py files to be created,
        relative to the repository root.
    #>

    return @(
        "backend/__init__.py",

        "backend/api/__init__.py",
        "backend/agents/__init__.py",
        "backend/rag/__init__.py",
        "backend/prompts/__init__.py",

        "backend/database/__init__.py",
        "backend/database/vector/__init__.py",
        "backend/database/relational/__init__.py",

        "backend/memory/__init__.py",
        "backend/services/__init__.py",
        "backend/schemas/__init__.py",
        "backend/models/__init__.py",

        "backend/core/__init__.py",
        "backend/config/__init__.py",

        "backend/evaluation/__init__.py",
        "backend/scripts/__init__.py",
        "backend/tests/__init__.py"
    )
}

function Get-GitKeepFileList {
    <#
        Returns the complete list of .gitkeep files to be created,
        relative to the repository root.
    #>

    return @(
        "backend/storage/.gitkeep",
        "backend/storage/uploads/.gitkeep",
        "backend/storage/cache/.gitkeep",
        "backend/storage/temp/.gitkeep",
        "docs/.gitkeep",
        "data/.gitkeep",
        "frontend/.gitkeep"
    )
}

function New-ProjectFolderStructure {
    <#
        Creates every directory returned by Get-ProjectFolderList.
    #>

    foreach ($folder in Get-ProjectFolderList) {
        New-ProjectItem -ItemType Directory -Path $folder
    }
}

function New-PythonPackageFiles {
    <#
        Creates every __init__.py file returned by Get-PythonPackageInitFileList.
    #>

    foreach ($file in Get-PythonPackageInitFileList) {
        New-ProjectItem -ItemType File -Path $file -Content ""
    }
}

function New-GitKeepFiles {
    <#
        Creates every .gitkeep file returned by Get-GitKeepFileList.
    #>

    foreach ($file in Get-GitKeepFileList) {
        New-ProjectItem -ItemType File -Path $file -Content ""
    }
}

# ==============================================================================
# CONTENT GENERATORS
# ==============================================================================

function Get-MainPyContent {
    <#
        Returns the contents of backend/main.py.
        Creates the FastAPI app and includes the router.
        Does not define endpoints directly.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    return @"
from fastapi import FastAPI

from api.router import router

app = FastAPI(title="$ProjectName")

app.include_router(router)
"@
}

function Get-RouterPyContent {
    <#
        Returns the contents of backend/api/router.py.
        Defines the health check endpoint.
    #>

    return @"
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}
"@
}

function Get-SettingsPyContent {
    <#
        Returns the contents of backend/config/settings.py.
        Uses pydantic-settings v2 with SettingsConfigDict.
    #>

    return @"
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_env: str = "development"
    log_level: str = "INFO"


settings = Settings()
"@
}

function Get-LoggingPyContent {
    <#
        Returns the contents of backend/core/logging.py.
        Configures application-wide logging based on settings.
    #>

    return @"
import logging

from config.settings import settings


def configure_logging() -> None:
    logging.basicConfig(
        level=settings.log_level,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )
"@
}

function Get-RequirementsTxtContent {
    <#
        Returns the contents of backend/requirements.txt.
    #>

    return @"
fastapi
uvicorn[standard]
pydantic
pydantic-settings
python-dotenv
pytest
httpx
"@
}

function Get-PyProjectTomlContent {
    <#
        Returns the contents of backend/pyproject.toml.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectSlug,

        [Parameter(Mandatory)]
        [string]$ScriptVersion
    )

    return @"
[project]
name = "$ProjectSlug"
version = "$ScriptVersion"
description = "Backend for $ProjectSlug"
requires-python = ">=3.11"
"@
}

function Get-EnvExampleContent {
    <#
        Returns the contents of backend/.env.example.
    #>

    return @"
# Environment variables. Copy this file to .env and fill in values.
APP_ENV=development
LOG_LEVEL=INFO
"@
}

function Get-TestHealthPyContent {
    <#
        Returns the contents of backend/tests/test_health.py.
        This test passes immediately against the generated main.py.
    #>

    return @"
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health_check_returns_ok() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
"@
}

function Get-TemplateMarkerContent {
    <#
        Returns the contents of .quaesitor-template.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [string]$ScriptVersion
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    return @"
template=$Script:TemplateName
version=$ScriptVersion
project=$ProjectName
generated=$timestamp
"@
}

function Get-ReadmeContent {
    <#
        Returns the contents of README.md. Only used if README.md is missing.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    return @"
# $ProjectName

## Overview

$ProjectName is an AI backend project scaffolded with the AI Project Initializer.

## Quick Start

``````bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
uvicorn main:app --reload
``````

## Project Structure

- ``backend/api`` - FastAPI routers
- ``backend/agents`` - Agent logic
- ``backend/rag`` - Retrieval pipeline
- ``backend/prompts`` - Prompt templates
- ``backend/database`` - Vector and relational storage
- ``backend/memory`` - Conversation memory
- ``backend/services`` - Supporting services
- ``backend/schemas`` - API request and response models
- ``backend/models`` - Domain models
- ``backend/core`` - Cross-cutting concerns
- ``backend/config`` - Application settings
- ``backend/evaluation`` - Quality evaluation
- ``backend/scripts`` - Operational scripts
- ``backend/tests`` - Tests
- ``backend/storage`` - Runtime-generated files
- ``frontend`` - Frontend application
- ``docs`` - Documentation
- ``data`` - Reference data

## License

See the LICENSE file for details.
"@
}

# ==============================================================================
# SCAFFOLD ENGINE
# ==============================================================================

function Invoke-ProjectScaffold {
    <#
        Orchestrates the full scaffold process: folders, package files,
        gitkeep files, generated content files, .gitignore updates, and
        the README.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [string]$ProjectSlug
    )

    Write-SectionHeader "Creating project structure..."
    New-ProjectFolderStructure

    Write-SectionHeader "Creating Python packages..."
    New-PythonPackageFiles

    Write-SectionHeader "Creating storage placeholders..."
    New-GitKeepFiles

    Write-SectionHeader "Generating starter files..."
    New-ProjectItem -ItemType File -Path "backend/main.py" -Content (Get-MainPyContent -ProjectName $ProjectName)
    New-ProjectItem -ItemType File -Path "backend/api/router.py" -Content (Get-RouterPyContent)
    New-ProjectItem -ItemType File -Path "backend/config/settings.py" -Content (Get-SettingsPyContent)
    New-ProjectItem -ItemType File -Path "backend/core/logging.py" -Content (Get-LoggingPyContent)
    New-ProjectItem -ItemType File -Path "backend/requirements.txt" -Content (Get-RequirementsTxtContent)
    New-ProjectItem -ItemType File -Path "backend/pyproject.toml" -Content (Get-PyProjectTomlContent -ProjectSlug $ProjectSlug -ScriptVersion $Script:ScriptVersion)
    New-ProjectItem -ItemType File -Path "backend/.env.example" -Content (Get-EnvExampleContent)
    New-ProjectItem -ItemType File -Path "backend/tests/test_health.py" -Content (Get-TestHealthPyContent)
    New-ProjectItem -ItemType File -Path ".quaesitor-template" -Content (Get-TemplateMarkerContent -ProjectName $ProjectName -ScriptVersion $Script:ScriptVersion)

    Write-SectionHeader "Checking README..."
    if (-not (Test-Path -Path "README.md" -PathType Leaf)) {
        New-ProjectItem -ItemType File -Path "README.md" -Content (Get-ReadmeContent -ProjectName $ProjectName)
    }
    else {
        $Script:SkippedItems.Add("File: README.md (already exists)")
    }

    Write-SectionHeader "Updating .gitignore..."
    Update-GitIgnore -RequiredEntries $Script:RequiredGitIgnoreEntries
}

# ==============================================================================
# SUMMARY
# ==============================================================================

function Write-InitializerSummary {
    <#
        Prints the full summary: created directories, created files,
        skipped items, and warnings. Does not display totals only.
    #>

    Write-Host ""
    Write-Host "Initialization Complete"
    Write-Host ""

    Write-Host "Created Directories : $($Script:CreatedDirectories.Count)"
    foreach ($item in $Script:CreatedDirectories) {
        Write-Host "  - $item"
    }

    Write-Host ""
    Write-Host "Created Files       : $($Script:CreatedFiles.Count)"
    foreach ($item in $Script:CreatedFiles) {
        Write-Host "  - $item"
    }

    Write-Host ""
    Write-Host "Skipped             : $($Script:SkippedItems.Count)"
    foreach ($item in $Script:SkippedItems) {
        Write-Host "  - $item"
    }

    Write-Host ""
    Write-Host "Warnings            : $($Script:WarningItems.Count)"
    foreach ($item in $Script:WarningItems) {
        Write-Host "  - $item"
    }

    Write-Host ""
}

# ==============================================================================
# MAIN
# ==============================================================================

function Invoke-Main {
    Write-Banner

    try {
        Test-RepositoryRoot
    }
    catch {
        Write-Host ""
        Write-Host "VALIDATION FAILED"
        Write-Host $_.Exception.Message
        exit $Script:ExitCodeValidationFailure
    }

    try {
        $identity = Get-ProjectIdentity
        Invoke-ProjectScaffold -ProjectName $identity.ProjectName -ProjectSlug $identity.ProjectSlug
        Write-InitializerSummary
    }
    catch {
        Write-Host ""
        Write-Host "RUNTIME FAILURE"
        Write-Host $_.Exception.Message
        exit $Script:ExitCodeRuntimeFailure
    }

    exit $Script:ExitCodeSuccess
}

Invoke-Main