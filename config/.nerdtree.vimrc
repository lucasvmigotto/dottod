" ============================================================================
" NERDTree - development-oriented ignore list
" ============================================================================
"
" Hide:
"   - dependency directories
"   - virtual environments
"   - build/compile output
"   - caches
"   - test/coverage artifacts
"   - generated files
"   - IDE/project metadata
"   - OS/editor junk
"
" Keep source files, configuration, documentation, and project files visible.
"

let NERDTreeIgnore = [
      \]

" ----------------------------------------------------------------------------
" Python
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '__pycache__$',
      \ '\.pytest_cache$',
      \ '\.mypy_cache$',
      \ '\.ruff_cache$',
      \ '\.hypothesis$',
      \ '\.tox$',
      \ '\.nox$',
      \ '\.pytype$',
      \ '\.pyre$',
      \ '\.pyright$',
      \ '\.dmypy\.json$',
      \ '\.pdm-build$',
      \ '\.pdm-python$',
      \ '\.eggs$',
      \ '\.egg-info$',
      \ '.*\.egg-info$',
      \ '\.coverage$',
      \ 'coverage\.xml$',
      \ 'htmlcov$',
      \ 'pip-wheel-metadata$',
      \ 'dist$',
      \ 'build$',
      \ 'site-packages$',
      \ '.*venv$',
      \ '.*virtualenv$',
      \ '.venv$',
      \ 'venv$',
      \ 'env$',
      \ '.env$',
      \ ]

" ----------------------------------------------------------------------------
" JavaScript / TypeScript / Node.js
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'node_modules$',
      \ '\.npm$',
      \ '\.pnpm-store$',
      \ '\.yarn$',
      \ '\.yarn-cache$',
      \ '\.yarnrc$',
      \ '\.parcel-cache$',
      \ '\.turbo$',
      \ '\.nx$',
      \ '\.angular$',
      \ '\.svelte-kit$',
      \ '\.nuxt$',
      \ '\.next$',
      \ '\.vite$',
      \ '\.astro$',
      \ '\.cache$',
      \ '\.eslintcache$',
      \ '\.stylelintcache$',
      \ '\.tsbuildinfo$',
      \ 'coverage$',
      \ '.nyc_output$',
      \ '\.nyc_output$',
      \ 'dist$',
      \ 'build$',
      \ 'out$',
      \ 'storybook-static$',
      \ 'playwright-report$',
      \ 'test-results$',
      \ 'cypress/videos$',
      \ 'cypress/screenshots$',
      \ ]

" ----------------------------------------------------------------------------
" Java / JVM / Maven / Gradle
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '\.gradle$',
      \ 'gradle/wrapper/dists$',
      \ 'build$',
      \ 'target$',
      \ 'out$',
      \ '\.idea$',
      \ '\.settings$',
      \ '\.classpath$',
      \ '\.project$',
      \ '\.factorypath$',
      \ '\.apt_generated$',
      \ '\.apt_generated_sources$',
      \ '\.generated$',
      \ 'bin$',
      \ ]

" ----------------------------------------------------------------------------
" Go
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'vendor$',
      \ '\.cache/go-build$',
      \ 'go-build$',
      \ '\.gocache$',
      \ '\.gopath$',
      \ 'bin$',
      \ 'coverage\.out$',
      \ 'coverage\.html$',
      \ ]

" ----------------------------------------------------------------------------
" Rust / Cargo
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'target$',
      \ '\.cargo$',
      \ ]

" ----------------------------------------------------------------------------
" C / C++ / CMake / Make
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'CMakeFiles$',
      \ 'CMakeCache\.txt$',
      \ 'cmake-build-debug$',
      \ 'cmake-build-release$',
      \ 'cmake-build-relwithdebinfo$',
      \ 'cmake-build-minsizerel$',
      \ '_build$',
      \ 'build-debug$',
      \ 'build-release$',
      \ 'build$',
      \ 'Debug$',
      \ 'Release$',
      \ 'x64$',
      \ 'x86$',
      \ 'obj$',
      \ 'bin$',
      \ '\.cache$',
      \ '\.ninja_deps$',
      \ '\.ninja_log$',
      \ 'compile_commands\.json$',
      \ ]

" ----------------------------------------------------------------------------
" C# / .NET / MSBuild
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'bin$',
      \ 'obj$',
      \ '\.vs$',
      \ '\.vscode$',
      \ '\.idea$',
      \ 'TestResults$',
      \ 'BenchmarkDotNet.Artifacts$',
      \ '\.sonarqube$',
      \ '\.nuget$',
      \ 'packages$',
      \ ]

" ----------------------------------------------------------------------------
" .NET / NuGet / ASP.NET generated artifacts
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'wwwroot/lib$',
      \ 'wwwroot/node_modules$',
      \ 'artifacts$',
      \ 'publish$',
      \ 'App_Data$',
      \ ]

" ----------------------------------------------------------------------------
" C / C++ package managers
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'vcpkg_installed$',
      \ '\.conan$',
      \ 'conan-build$',
      \ 'conan-.*$',
      \ '_deps$',
      \ ]

" ----------------------------------------------------------------------------
" Docker
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '\.docker$',
      \ ]

" ----------------------------------------------------------------------------
" Generic build / compilation output
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'build$',
      \ 'dist$',
      \ 'out$',
      \ 'output$',
      \ 'release$',
      \ 'debug$',
      \ 'Debug$',
      \ 'Release$',
      \ 'bin$',
      \ 'obj$',
      \ '_build$',
      \ 'artifacts$',
      \ 'generated$',
      \ '\.generated$',
      \ 'generated-code$',
      \ 'generated-sources$',
      \ 'generated-resources$',
      \ ]

" ----------------------------------------------------------------------------
" Test / coverage artifacts
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'coverage$',
      \ 'cover$',
      \ 'htmlcov$',
      \ '\.coverage$',
      \ 'coverage\.xml$',
      \ 'lcov-report$',
      \ '\.nyc_output$',
      \ 'test-results$',
      \ 'test-results\.xml$',
      \ 'junit\.xml$',
      \ 'pytest-report$',
      \ 'playwright-report$',
      \ ]

" ----------------------------------------------------------------------------
" General caches
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '\.cache$',
      \ '\.tmp$',
      \ '\.temp$',
      \ 'tmp$',
      \ 'temp$',
      \ '\.sass-cache$',
      \ '\.parcel-cache$',
      \ '\.eslintcache$',
      \ '\.stylelintcache$',
      \ ]

" ----------------------------------------------------------------------------
" IDE / editor metadata
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '\.idea$',
      \ '\.vs$',
      \ '\.settings$',
      \ '\.classpath$',
      \ '\.project$',
      \ '\.factorypath$',
      \ '\.metadata$',
      \ '\.recommenders$',
      \ ]

" ----------------------------------------------------------------------------
" Version control internals
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '\.git$',
      \ '\.hg$',
      \ '\.svn$',
      \ '\.bzr$',
      \ ]

" ----------------------------------------------------------------------------
" OS / filesystem junk
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '\.DS_Store$',
      \ 'Thumbs\.db$',
      \ 'ehthumbs\.db$',
      \ 'Desktop\.ini$',
      \ ]

" ----------------------------------------------------------------------------
" Vim / editor generated files
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '.*\.swp$',
      \ '.*\.swo$',
      \ '.*\.swn$',
      \ '.*~$',
      \ '\.vim\.swap$',
      \ ]

" ----------------------------------------------------------------------------
" JavaScript / TypeScript generated files
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '.*\.js\.map$',
      \ '.*\.mjs\.map$',
      \ '.*\.cjs\.map$',
      \ '.*\.tsbuildinfo$',
      \ ]

" ----------------------------------------------------------------------------
" Java generated / compiled files
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '.*\.class$',
      \ '.*\.jar$',
      \ ]

" ----------------------------------------------------------------------------
" C / C++ compiled artifacts
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '.*\.o$',
      \ '.*\.obj$',
      \ '.*\.a$',
      \ '.*\.lib$',
      \ '.*\.so$',
      \ '.*\.dylib$',
      \ '.*\.dll$',
      \ '.*\.exe$',
      \ ]

" ----------------------------------------------------------------------------
" CMake / compiler generated files
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ 'CMakeFiles$',
      \ 'CMakeCache\.txt$',
      \ 'cmake_install\.cmake$',
      \ 'install_manifest\.txt$',
      \ 'Makefile$',
      \ ]

" ----------------------------------------------------------------------------
" Logs
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '.*\.log$',
      \ 'logs$',
      \ ]

" ----------------------------------------------------------------------------
" Temporary / backup files
" ----------------------------------------------------------------------------
let NERDTreeIgnore += [
      \ '.*\.bak$',
      \ '.*\.tmp$',
      \ '.*\.temp$',
      \ '.*\.orig$',
      \ '.*\.rej$',
      \ ]
