# Development Guide for marker-groups.nvim

This guide covers development setup, testing, debugging, and maintenance procedures for the marker-groups.nvim plugin.

## Table of Contents

- [Quick Start](#quick-start)
- [Development Environment](#development-environment)
- [Testing Framework](#testing-framework)
- [Debugging and Logging](#debugging-and-logging)
- [Health Checks](#health-checks)
- [Code Quality](#code-quality)
- [CI/CD Pipeline](#cicd-pipeline)
- [Architecture Overview](#architecture-overview)
- [Contributing](#contributing)

## Quick Start

```bash
# Clone and setup development environment
git clone https://github.com/yourusername/marker-groups.nvim.git
cd marker-groups.nvim

# Install dependencies and setup
make dev-setup

# Run all tests
make test

# Start development with watch mode
make test-watch
```

## Development Environment

### Prerequisites

- **Neovim ≥ 0.8.0** (recommended: latest stable)
- **plenary.nvim** (required for testing)
- **telescope.nvim** (optional, for full functionality)
- **stylua** (optional, for code formatting)
- **lua-language-server** (optional, for enhanced linting)

### Plugin Structure

```
lua/marker-groups/
├── init.lua                    # Main plugin entry point
├── config.lua                  # Configuration management
├── state.lua                   # State management and data structures
├── groups.lua                  # Group operations and management
├── markers.lua                 # Marker operations and tracking
├── commands.lua                # Neovim command definitions
├── keymaps.lua                 # Default keybinding setup
├── health.lua                  # Health check integration
├── persistence.lua             # Data persistence and backup
├── feedback.lua                # User notification system
├── error_handling.lua          # Error handling documentation
├── telescope.lua               # Telescope integration
├── ui/
│   ├── virtual_text.lua        # Virtual text display
│   └── floating.lua            # Floating window interface
└── utils/
    ├── logger.lua              # Logging system
    └── debug.lua               # Debug utilities

tests/
├── test_runner.lua             # Test execution framework
├── test_config.lua             # Shared test configuration
├── unit/                       # Unit tests
│   ├── config_spec.lua
│   ├── state_spec.lua
│   └── logger_spec.lua
└── integration/                # Integration tests
    └── commands_spec.lua
```

## Testing Framework

### Running Tests

```bash
# Run all tests
make test

# Run specific test suites
make test-unit                  # Unit tests only
make test-integration          # Integration tests only

# Run specific test file
make test-file FILE=tests/unit/config_spec.lua

# Watch mode for continuous testing
make test-watch
```

### Test Commands (Available in Neovim)

```vim
:MarkerGroupsTestAll           " Run all tests
:MarkerGroupsTestUnit          " Run unit tests
:MarkerGroupsTestIntegration   " Run integration tests
:MarkerGroupsTestFile <file>   " Run specific test file
:MarkerGroupsTestWatch [suite] " Watch tests for changes
```

### Writing Tests

#### Unit Test Example

```lua
-- tests/unit/example_spec.lua
local assert = require('luassert')
local module = require('marker-groups.module')

describe('module functionality', function()
  before_each(function()
    -- Setup for each test
  end)
  
  after_each(function()
    -- Cleanup after each test
  end)
  
  it('should perform expected operation', function()
    local result = module.some_function('input')
    assert.are.equal('expected', result)
  end)
end)
```

#### Integration Test Example

```lua
-- tests/integration/feature_spec.lua
local assert = require('luassert')

describe('feature integration', function()
  it('should execute command without errors', function()
    assert.has_no.errors(function()
      vim.cmd('MarkerGroupsCreate test-group')
    end)
  end)
end)
```

### Test Configuration

Tests use isolated environments with temporary directories and test-specific configuration. See `tests/test_config.lua` for shared utilities.

## Debugging and Logging

### Logging System

The plugin includes a comprehensive logging system with multiple levels and a dedicated log buffer.

#### Log Levels

- **debug**: Detailed debugging information
- **info**: General information messages
- **warn**: Warning messages for potential issues
- **error**: Error messages for failures

#### Logging Commands

```vim
:MarkerGroupsShowLogs          " Open log buffer
:MarkerGroupsClearLogs         " Clear log buffer
:MarkerGroupsLogLevel [level]  " Get/set log level
:MarkerGroupsWriteLogs [file]  " Export logs to file
:MarkerGroupsLogStatus         " Show logger status
```

#### Programmatic Logging

```lua
local logger = require('marker-groups.utils.logger')

logger.debug('Debug message')
logger.info('Info message')
logger.warn('Warning message')
logger.error('Error message')

-- Show log buffer
logger.show()

-- Get log status
local status = logger.get_status()
```

### Debug Utilities

The debug system provides comprehensive state inspection and validation tools.

#### Debug Commands

```vim
:MarkerGroupsDebugMode [on|off]  " Toggle debug mode
:MarkerGroupsDebugState          " Show plugin state
:MarkerGroupsDebugDump [file]    " Write state dump to file
:MarkerGroupsDebugGroup [name]   " Inspect specific group
:MarkerGroupsDebugValidate       " Validate state integrity
:MarkerGroupsDebugMemory         " Show memory usage
```

#### Debug API

```lua
local debug = require('marker-groups.utils.debug')

-- Enable debug mode
debug.set_debug_mode(true)

-- Show current state
debug.show_state()

-- Inspect specific group
debug.inspect_group('group-name')

-- Validate state integrity
local validation = debug.validate_state()
```

## Health Checks

The plugin includes comprehensive health checks for environment validation.

### Running Health Checks

```vim
:checkhealth marker-groups     " Run health checks
:MarkerGroupsHealth            " Alternative command
```

### Health Check Coverage

- **Neovim Version**: Ensures ≥ 0.8.0 compatibility
- **Required APIs**: Validates essential Neovim APIs
- **Dependencies**: Checks optional dependencies (Telescope)
- **Plugin State**: Verifies initialization and configuration
- **Data Directory**: Tests directory existence and permissions
- **Performance**: Measures configuration access speed
- **JSON Support**: Confirms persistence capabilities

## Code Quality

### Formatting

```bash
make format                    # Format code with stylua
```

### Linting

```bash
make lint                      # Run Lua syntax checks
```

### Code Style

The project follows standard Lua conventions with these specifics:

- **Indentation**: 2 spaces
- **Line Length**: 80-100 characters preferred
- **Naming**: snake_case for variables, PascalCase for modules
- **Documentation**: LuaLS annotations for type safety

### Pre-commit Hooks

Consider setting up pre-commit hooks for automatic formatting and linting:

```bash
# .git/hooks/pre-commit
#!/bin/bash
make lint
make format
```

## CI/CD Pipeline

### GitHub Actions

The project uses GitHub Actions for continuous integration with:

- **Multi-platform Testing**: Ubuntu and macOS
- **Neovim Version Matrix**: v0.8.0, v0.9.0, stable, nightly
- **Code Quality Checks**: Linting and formatting validation
- **Health Check Validation**: Automated health check execution

### Local CI Testing

```bash
# Run CI-equivalent tests locally
make ci-test
```

## Architecture Overview

### Core Components

1. **State Management** (`state.lua`): Centralized data management with event system
2. **Configuration** (`config.lua`): Plugin configuration with validation
3. **Groups/Markers** (`groups.lua`, `markers.lua`): Core functionality
4. **UI Components** (`ui/`): Virtual text and floating window interfaces
5. **Persistence** (`persistence.lua`): Data saving with backup/recovery
6. **Integration** (`telescope.lua`): Telescope picker integration

### Event System

The plugin uses an event-driven architecture for state changes:

```lua
-- Subscribe to events
local unsubscribe = state.subscribe('group_added', function(data)
  print('Group added:', data.group_name)
end)

-- Unsubscribe when done
unsubscribe()
```

### Error Handling

All operations use a consistent Result pattern:

```lua
local result = groups.create_group('new-group')
if result.success then
  print('Success:', result.data)
else
  print('Error:', result.error)
end
```

## Contributing

### Development Workflow

1. **Fork and Clone**: Fork the repository and clone locally
2. **Setup Environment**: Run `make dev-setup`
3. **Create Branch**: Create feature branch from `main`
4. **Develop**: Write code following style guidelines
5. **Test**: Ensure all tests pass with `make test`
6. **Document**: Update documentation as needed
7. **Submit PR**: Create pull request with clear description

### Testing Guidelines

- **Write Tests**: Add tests for new functionality
- **Test Coverage**: Aim for high test coverage
- **Integration Tests**: Test command integration
- **Edge Cases**: Test error conditions and edge cases

### Code Review Checklist

- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Error handling implemented
- [ ] Performance considerations addressed
- [ ] Backward compatibility maintained

### Release Process

1. **Version Bump**: Update version in `init.lua`
2. **Changelog**: Update CHANGELOG.md
3. **Testing**: Run full test suite
4. **Tag Release**: Create git tag
5. **Documentation**: Update README if needed

## Troubleshooting

### Common Issues

#### Tests Failing

```bash
# Check dependencies
nvim --version
# Ensure plenary.nvim is installed

# Run with verbose output
make test-unit VERBOSE=1
```

#### Plugin Not Loading

```vim
:checkhealth marker-groups     " Check health status
:MarkerGroupsDebugState        " Inspect plugin state
:MarkerGroupsShowLogs          " Check for errors
```

#### Performance Issues

```vim
:MarkerGroupsDebugMemory       " Check memory usage
:MarkerGroupsLogLevel debug    " Enable debug logging
```

### Debug Information Collection

When reporting issues, include:

1. **Health Check Output**: `:checkhealth marker-groups`
2. **Debug State**: `:MarkerGroupsDebugState`
3. **Log Output**: `:MarkerGroupsShowLogs`
4. **Neovim Version**: `nvim --version`
5. **Configuration**: Your plugin configuration

## Resources

- **Plugin Repository**: [GitHub](https://github.com/yourusername/marker-groups.nvim)
- **Issue Tracker**: [GitHub Issues](https://github.com/yourusername/marker-groups.nvim/issues)
- **Neovim Documentation**: [help nvim](https://neovim.io/doc/)
- **Lua Documentation**: [lua.org](https://www.lua.org/docs.html)
- **Testing Framework**: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

---

**Happy developing! 🚀**

For questions or support, please open an issue on GitHub or start a discussion in the repository.