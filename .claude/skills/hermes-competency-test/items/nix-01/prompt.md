`task/override.nix` is my local override for the vendored module in `task/upstream/metrics-agent.nix`. I want two things from it: the service should no longer start at boot (I'll start it by hand when I need it), and it should restart always instead of only on failure. My other settings in the override should stay as they are.

Right now it doesn't evaluate:

```
$ nix-instantiate --eval --strict task/eval.nix
error: The option `systemd.services.metrics-agent.serviceConfig.Restart' has conflicting definition values:
...
```

Fix `task/override.nix` in place so both of my goals actually take effect. Don't edit the upstream module or `task/eval.nix`. In your final answer, explain what was wrong and why your fix works.
