# Contributing to Mintis Sync

Thanks for your interest in contributing!

## Development Setup

1. Clone the repository
2. Make your changes
3. Test with a Bedrock installation
4. Submit a pull request

## Testing

Before submitting a PR, test your changes:

```bash
# Test database sync
bash sync.sh production development --skip-assets

# Test assets sync
bash sync.sh production development --skip-db

# Test full sync
bash sync.sh production development
```

## Reporting Issues

When reporting issues, include:

- Your Bedrock version
- WP-CLI version (`wp --version`)
- Single-site or multisite
- Full error message
- Steps to reproduce

## Code Style

- Use tabs for indentation
- Follow existing code style
- Add comments for complex logic
- Keep functions focused and small

## Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
