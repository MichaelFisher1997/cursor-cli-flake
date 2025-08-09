# Cursor CLI Nix Flake

A Nix flake that packages the [Cursor](https://cursor.com) CLI for reproducible installation on NixOS and other Nix-based systems.

## Features

- ✅ Supports both x86_64-linux and aarch64-linux architectures
- ✅ Uses `autoPatchelfHook` for proper binary patching on NixOS  
- ✅ Includes all necessary runtime dependencies
- ✅ Reproducible builds with pinned hashes
- ✅ Easy version updates via included script
- ✅ CI testing with GitHub Actions

## Quick Start

### Run directly (no installation)

```bash
nix run github:YOUR_USERNAME/cursor-cli-flake
```

### Install to user profile

```bash
nix profile install github:YOUR_USERNAME/cursor-cli-flake
```

### Use with Home Manager

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    cursor-flake.url = "github:YOUR_USERNAME/cursor-cli-flake";
  };

  outputs = { self, nixpkgs, home-manager, cursor-flake, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          home.username = "me";
          home.homeDirectory = "/home/me";
          home.packages = [ cursor-flake.packages.${system}.default ];
        }
      ];
    };
  };
}
```

### Use in NixOS configuration

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cursor-flake.url = "github:YOUR_USERNAME/cursor-cli-flake";
  };

  outputs = { self, nixpkgs, cursor-flake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            cursor-flake.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

## How URLs and Hashes Were Obtained

The download URLs were discovered by analyzing the install script at https://cursor.com/install:

- x86_64: `https://downloads.cursor.com/lab/2025.08.08-f57cb59/linux/x64/agent-cli-package.tar.gz`
- aarch64: `https://downloads.cursor.com/lab/2025.08.08-f57cb59/linux/arm64/agent-cli-package.tar.gz`

Hashes were computed using:

```bash
# x86_64 hash
nix store prefetch-file 'https://downloads.cursor.com/lab/2025.08.08-f57cb59/linux/x64/agent-cli-package.tar.gz' --hash-type sha256
# Result: sha256-ikoxUvpLMngDOlHawq7i69mOcPGkV8q1capDU83QMWs=

# aarch64 hash  
nix store prefetch-file 'https://downloads.cursor.com/lab/2025.08.08-f57cb59/linux/arm64/agent-cli-package.tar.gz' --hash-type sha256
# Result: sha256-AwwfNJU4+ndvO5DAY7cfpKBVqQz7QiCB4IPY57Ri2iQ=
```

## Updating to New Versions

Use the included update script:

```bash
# Update to latest version (auto-detected)
./update.sh

# Update to specific version
./update.sh 2025.08.15-abc1234
```

The script will:
1. Fetch new URLs for both architectures
2. Compute new SHA256 hashes using `nix store prefetch-file`
3. Update `flake.nix` in-place with the new version and hashes

## Development

### Local testing

```bash
# Build the package
nix build .#cursor-cli

# Test the binary
./result/bin/cursor --help

# Run directly
nix run .

# Check flake
nix flake check
```

### Checking dynamic libraries

If the binary fails to run, check missing libraries:

```bash
ldd ./result/bin/cursor || true
```

Common missing libraries that might need to be added to `buildInputs`:
- `libsecret` - for credential storage
- `gtk3` - for GUI components
- `openssl` - for SSL/TLS
- `curl` - for HTTP requests
- `zlib` - for compression

### Archive structure

The downloaded tar.gz contains:
```
dist-package/
├── cursor-agent       # Main CLI binary  
├── package.json       # Package metadata
├── build/
│   └── node_sqlite3.node
├── node               # Node.js runtime
├── rg                 # ripgrep binary
└── index.js           # Entry script
```

## Troubleshooting

### Binary won't run on NixOS
The flake uses `autoPatchelfHook` to fix library paths. If you still get library errors:

1. Check what's missing: `ldd ./result/bin/cursor`
2. Add missing libraries to `buildInputs` in `flake.nix`
3. Rebuild: `nix build .#cursor-cli`

### Version format changes
If Cursor changes their URL structure, update the `sources` mapping in `flake.nix` and the `update.sh` script accordingly.

### Unsupported architecture
This flake currently supports `x86_64-linux` and `aarch64-linux`. Other architectures need upstream support from Cursor first.

## License

This packaging is provided as-is. Cursor CLI itself has its own license terms - see https://cursor.com for details.