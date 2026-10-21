The flake stopped evaluating after my last edit. `nix flake check` fails with:

```
error: A definition for option `boot.kernelParams' is not of type `list of string'. Definition values:
- In `/nix/store/...-source/modules/bootloader.nix': "splash"
```

It's because `modules/bootloader.nix` sets `kernelParams` to a bare string instead of a list. Explain why that causes this error. Do not change any files.
