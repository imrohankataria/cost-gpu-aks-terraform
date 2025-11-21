# Contributing to AKS GPU Cost Optimization

First off, thank you for considering contributing to this project! It's people like you that make this solution better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our commitment to creating a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Environment details** (Azure region, VM sizes, Kubernetes version)
- **Relevant logs or error messages**
- **Screenshots** if applicable

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- **Clear description** of the enhancement
- **Use case** - why would this be useful?
- **Proposed solution** if you have one
- **Alternatives considered**

### Pull Requests

1. **Fork** the repository
2. **Create a branch** from `main`
3. **Make your changes**
4. **Test thoroughly**
5. **Update documentation**
6. **Submit pull request**

## Development Setup

### Prerequisites

- Azure CLI (v2.30.0+)
- Terraform (v1.0+)
- kubectl (v1.28+)
- Git
- Azure subscription with GPU quota

### Local Development

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/cost-gpu-aks-terraform.git
cd cost-gpu-aks-terraform

# Create a branch
git checkout -b feature/my-new-feature

# Make changes
# ...

# Test your changes
./scripts/deploy.sh  # In a test environment!

# Commit with meaningful message
git commit -m "Add feature: description"

# Push to your fork
git push origin feature/my-new-feature
```

## Guidelines

### Terraform Code

- Use consistent formatting: `terraform fmt -recursive`
- Add comments for complex logic
- Use variables for configurable values
- Follow HashiCorp naming conventions
- Include descriptions for variables and outputs

Example:
```hcl
variable "example_variable" {
  description = "Clear description of what this does"
  type        = string
  default     = "sensible-default"
}
```

### Kubernetes Manifests

- Use YAML formatting (2 spaces)
- Include resource limits and requests
- Add labels for organization
- Include comments for non-obvious settings
- Use namespaces appropriately

Example:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    # ... rest of spec
```

### Shell Scripts

- Use bash with `set -e` at the top
- Add comments for complex operations
- Use functions for reusable code
- Include error handling
- Use meaningful variable names

Example:
```bash
#!/bin/bash
set -e

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Main logic
print_status "Starting operation"
# ... rest of script
```

### Documentation

- Use Markdown formatting
- Include code examples
- Add links to external resources
- Keep language clear and concise
- Update README if adding features

## Testing

### Before Submitting PR

1. **Validate Terraform:**
   ```bash
   cd terraform
   terraform fmt -check -recursive
   terraform validate
   ```

2. **Validate YAML:**
   ```bash
   for file in kubernetes/manifests/*.yaml; do
       python3 -c "import yaml; yaml.safe_load_all(open('$file'))"
   done
   ```

3. **Test Shell Scripts:**
   ```bash
   for script in scripts/*.sh; do
       bash -n "$script"
   done
   ```

4. **Test Deployment** (if possible):
   - Deploy to test environment
   - Verify all components work
   - Check monitoring dashboards
   - Test cleanup script

### What to Test

- ✅ Terraform deployment
- ✅ Kubernetes manifests apply
- ✅ GPU nodes provision correctly
- ✅ Monitoring stack works
- ✅ Grafana dashboards display data
- ✅ Cost analysis script runs
- ✅ Cleanup works properly

## Commit Messages

Use clear, descriptive commit messages:

```
Add feature: Short description

Longer explanation if needed. Explain what changed and why.
Include any relevant issue numbers.

Fixes #123
```

### Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Start with capital letter
- Keep first line under 72 characters
- Reference issues and PRs when relevant
- Explain the "why" not just the "what"

## Documentation

### When to Update Documentation

Update documentation when:
- Adding new features
- Changing existing behavior
- Fixing bugs that affect usage
- Adding configuration options
- Changing prerequisites

### Documentation Files

- `README.md` - Main overview and quick start
- `docs/ARCHITECTURE.md` - Architecture details
- `docs/COST_OPTIMIZATION.md` - Cost optimization strategies
- `docs/TROUBLESHOOTING.md` - Common issues and solutions
- `docs/EXAMPLES.md` - Usage examples
- `docs/FAQ.md` - Frequently asked questions

## Code Review Process

### What We Look For

1. **Correctness** - Does it work as intended?
2. **Security** - Are there any security concerns?
3. **Performance** - Is it efficient?
4. **Maintainability** - Is the code readable?
5. **Documentation** - Is it well documented?
6. **Testing** - Has it been tested?

### Response Time

- We aim to review PRs within 2-3 business days
- Complex changes may take longer
- We appreciate your patience!

## Areas for Contribution

### High Priority

- 🔧 Multi-region deployment support
- 🔧 Advanced GPU scheduling (MIG, time-slicing)
- 🔧 Enhanced cost analytics
- 🔧 CI/CD pipeline integration
- 📖 More usage examples

### Medium Priority

- 🔧 Additional monitoring dashboards
- 🔧 Integration with external tools (Datadog, etc.)
- 🔧 Automated testing framework
- 📖 Video tutorials
- 📖 Blog posts / case studies

### Good First Issues

- 📖 Improve documentation clarity
- 🐛 Fix typos
- 🔧 Add validation to scripts
- 📖 Add more examples
- 🔧 Enhance error messages

## Questions?

If you have questions about contributing:
- Open a [GitHub Discussion](https://github.com/imrohankataria/cost-gpu-aks-terraform/discussions)
- Comment on relevant issues
- Reach out to maintainers

## Recognition

Contributors will be:
- Listed in release notes
- Mentioned in README (for significant contributions)
- Thanked publicly in project updates

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing!** 🎉
