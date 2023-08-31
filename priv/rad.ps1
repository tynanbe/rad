$self = "rad"
$build_dir = "./build/dev/javascript/${self}"
$main_module = "${build_dir}/${self}.mjs"
$run = "gleam.main"
$run_module = "${build_dir}/${run}.mjs"

function Fail {
  param($message)
  Write-Error "${message}" 2> $Null
  Write-Host "`e[91m$($Error[0])`e[0m"
  Exit 1
}

$config = "gleam.toml"
if (-not (Test-Path -Type Leaf "./${config}")) {
  Fail "error: ``${config}`` not found; ``${self}`` must be invoked from a Gleam project's base directory"
}

# Detect JavaScript runtime
$runtime = "node"
if (Select-String -Pattern '^\s*runtime\s*=\s*"deno"' -Path "./${config}") {
  $runtime = "deno"
}

$snag = ""
foreach ($dependency in "gleam", "${runtime}") {
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

# Compile if necessary.
#
# Redirect stdout to stderr, keeping stdout clear for the given task.
#
if (-not (Test-Path -Type Leaf "${main_module}")) {
  gleam build --target=javascript | Out-Host
  if ($LastExitCode -ne 0) {
    Exit 1
  }
}
if (-not (Test-Path -Type Leaf "${main_module}")) {
  Fail "error: ``${main_module}`` not found; try ``gleam add --dev ${self}``"
}
if (-not (Test-Path -Type Leaf "${run_module}")) {
  Copy-Item -Path "./priv/${run}.mjs" -Destination "${run_module}"
  if ($LastExitCode -ne 0) {
    Exit 1
  }
}

if ("${runtime}" -eq "deno") {
  & deno run `
    --allow-all `
    --unstable `
    "${run_module}" `
    @Args
} else {
  & node `
    --experimental-fetch `
    --experimental-repl-await `
    --no-warnings `
    --title="${self}" `
    "${run_module}" `
    @Args
}
