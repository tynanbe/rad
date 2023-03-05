$self = "rad"
$module = "./build/dev/javascript/${self}/${self}.mjs"

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
if (-not (Test-Path -Type Leaf "${module}")) {
  gleam build --target=javascript | Out-Host
  if ($LastExitCode -ne 0) {
    Exit 1
  }
}
if (-not (Test-Path -Type Leaf "${module}")) {
  Fail "error: ``${module}`` not found; try ``gleam add --dev ${self}``"
}

$script = "import('${module}').then(module => module.main())"
if ("${runtime}" -eq "deno") {
  & deno `
    eval "${script}" `
    --unstable `
    -- @Args
} else {
  & node `
    --experimental-fetch `
    --experimental-repl-await `
    --no-warnings `
    --title="${self}" `
    --eval="${script}" `
    -- @Args
}
