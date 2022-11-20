$self = "rad"
$module = "./build/dev/javascript/${self}/${self}.mjs"

function Fail {
  param($message)
  Write-Error "${message}" 2> $Null
  Write-Host "`e[91m$($Error[0])`e[0m"
  Exit 1
}

$snag = ""
foreach ($dependency in "gleam", "node") {
  if (-not (Get-Command "${dependency}" -ErrorAction SilentlyContinue)) {
    if ("${snag}" -ne "") {
      $snag += "`n"
    }
    $snag += "error: ``${dependency}`` required but not found"
  }
}
if ("${snag}" -ne "") {
  Fail "${snag}"
}

$config = "gleam.toml"
if (-not (Test-Path -Type Leaf "./${config}")) {
  Fail "error: ``${config}`` not found; ``${self}`` must be invoked from a Gleam project's base directory"
}

# Compile if necessary.
#
# Redirect stdout to stderr, keeping stdout clear for the given task.
#
if (-not (Test-Path -Type Leaf "${module}")) {
  gleam build --target=javascript | Out-Host
  if ($LastExitCode -ne 0) {
    Exit 1
  }
}
if (-not (Test-Path -Type Leaf "${module}")) {
  Fail "error: ``${module}`` not found; try ``gleam add --dev ${self}``"
}

& node `
  --experimental-fetch `
  --experimental-repl-await `
  --no-warnings `
  --title="${self}" `
  --eval="import('${module}').then(module => module.main())" `
  -- @Args
