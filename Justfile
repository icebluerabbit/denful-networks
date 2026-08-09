default:
    @just --list

format:
    cd dev && nix fmt

test:
    nix flake check ./test --extra-experimental-features "nix-command flakes"
