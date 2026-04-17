param(
    [string]$BaseUrl = "http://localhost:8081",
    [double]$Tolerance = 0.0001
)

$ErrorActionPreference = "Stop"

function Invoke-Json {
    param([string]$Path)

    Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + $Path) -Method Get
}

function ConvertTo-ObjectList {
    param([object]$Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array]) {
        return $Value
    }

    return @($Value)
}

function Get-FirstExistingProperty {
    param(
        [object]$InputObject,
        [string[]]$CandidateNames
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($name in $CandidateNames) {
        $property = $InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function Get-CoordinatePair {
    param([object]$Geometry)

    if ($null -eq $Geometry) {
        throw "Geometry payload was null."
    }

    if ($Geometry -is [string]) {
        try {
            $Geometry = $Geometry | ConvertFrom-Json
        }
        catch {
        }
    }

    $geoJsonCoordinates = Get-FirstExistingProperty $Geometry @("coordinates", "COORDINATES")
    if ($null -ne $geoJsonCoordinates -and $geoJsonCoordinates.Count -ge 2) {
        return @{
            Lon = [double]$geoJsonCoordinates[0]
            Lat = [double]$geoJsonCoordinates[1]
        }
    }

    $point = Get-FirstExistingProperty $Geometry @("sdoPoint", "SDO_POINT", "point", "POINT")
    if ($null -ne $point) {
        $x = Get-FirstExistingProperty $point @("x", "X", "longitude", "LONGITUDE", "lon", "LON")
        $y = Get-FirstExistingProperty $point @("y", "Y", "latitude", "LATITUDE", "lat", "LAT")

        if ($null -ne $x -and $null -ne $y) {
            return @{
                Lon = [double]$x
                Lat = [double]$y
            }
        }
    }

    $ordinates = Get-FirstExistingProperty $Geometry @("sdoOrdinates", "SDO_ORDINATES", "ordinates", "ORDINATES")
    if ($null -ne $ordinates -and $ordinates.Count -ge 2) {
        return @{
            Lon = [double]$ordinates[0]
            Lat = [double]$ordinates[1]
        }
    }

    $x = Get-FirstExistingProperty $Geometry @("x", "X")
    $y = Get-FirstExistingProperty $Geometry @("y", "Y")
    if ($null -ne $x -and $null -ne $y) {
        return @{
            Lon = [double]$x
            Lat = [double]$y
        }
    }

    $payload = $Geometry | ConvertTo-Json -Depth 10 -Compress
    throw "Could not extract longitude and latitude from geometry payload: $payload"
}

function Assert-Approximate {
    param(
        [double]$Actual,
        [double]$Expected,
        [string]$Label
    )

    if ([Math]::Abs($Actual - $Expected) -gt $Tolerance) {
        throw "$Label mismatch. Expected $Expected but got $Actual."
    }
}

function Get-OpenApiDocument {
    $candidatePaths = @(
        "/v3/api-docs",
        "/api-docs",
        "/openapi",
        "/openapi.json"
    )

    foreach ($path in $candidatePaths) {
        try {
            $document = Invoke-Json $path
            $openApiVersion = Get-FirstExistingProperty $document @("openapi")
            if ($openApiVersion -and $openApiVersion.ToString().StartsWith("3.")) {
                return @{
                    Path     = $path
                    Document = $document
                }
            }
        }
        catch {
        }
    }

    throw "No OpenAPI 3 document was found on the known DB2REST documentation endpoints."
}

$health = Invoke-Json "/actuator/health"
if ((Get-FirstExistingProperty $health @("status")) -ne "UP") {
    throw "DB2REST health endpoint did not report UP."
}

$openApi = Get-OpenApiDocument
$openApiPaths = @($openApi.Document.paths.PSObject.Properties.Name)
$expectedApiPaths = @(
    "/v1/rdbms/{dbId}/{tableName}"
)

foreach ($expectedPath in $expectedApiPaths) {
    if (-not ($openApiPaths | Where-Object { $_ -ieq $expectedPath })) {
        throw "Expected OpenAPI path '$expectedPath' was not present in $($openApi.Path)."
    }
}

$customers = ConvertTo-ObjectList (Invoke-Json "/v1/rdbms/oracle/CUSTOMERS")
$fieldSites = ConvertTo-ObjectList (
    Invoke-Json "/v1/rdbms/oracle/FIELD_SITES?fields=SITE_ID,CUSTOMER_ID,SITE_NAME,SITE_TYPE,STATUS,INSTALLED_ON,LOCATION_GEOJSON"
)
$workOrders = ConvertTo-ObjectList (Invoke-Json "/v1/rdbms/oracle/WORK_ORDERS")

if ($customers.Count -ne 3) {
    throw "Expected 3 customers but found $($customers.Count)."
}

if ($fieldSites.Count -ne 3) {
    throw "Expected 3 field_sites rows but found $($fieldSites.Count)."
}

if ($workOrders.Count -ne 4) {
    throw "Expected 4 work_orders rows but found $($workOrders.Count)."
}

$vancouverSite = $fieldSites | Where-Object {
    (Get-FirstExistingProperty $_ @("site_name", "SITE_NAME")) -eq "Vancouver Control Point"
} | Select-Object -First 1

if ($null -eq $vancouverSite) {
    throw "Could not find the seeded 'Vancouver Control Point' geospatial row."
}

$geometry = Get-FirstExistingProperty $vancouverSite @("location_geojson", "LOCATION_GEOJSON", "location", "LOCATION")
$coordinates = Get-CoordinatePair $geometry

Assert-Approximate -Actual $coordinates.Lon -Expected -123.1207 -Label "Longitude"
Assert-Approximate -Actual $coordinates.Lat -Expected 49.2827 -Label "Latitude"

$summary = [pscustomobject]@{
    HealthStatus         = (Get-FirstExistingProperty $health @("status"))
    OpenApiPath          = $openApi.Path
    OpenApiVersion       = (Get-FirstExistingProperty $openApi.Document @("openapi"))
    CustomerRows         = $customers.Count
    FieldSiteRows        = $fieldSites.Count
    WorkOrderRows        = $workOrders.Count
    FieldSitesProjection = "SITE_ID,CUSTOMER_ID,SITE_NAME,SITE_TYPE,STATUS,INSTALLED_ON,LOCATION_GEOJSON"
    ValidatedGeometry    = [pscustomobject]@{
        Site      = "Vancouver Control Point"
        Longitude = $coordinates.Lon
        Latitude  = $coordinates.Lat
    }
}

$summary | ConvertTo-Json -Depth 6