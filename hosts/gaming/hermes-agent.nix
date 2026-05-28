{ pkgs, ... }:

# Ollama (CUDA backend) + Hermes Agent for gaming.
#
# Ollama exposes an OpenAI-compatible API at http://localhost:11434/v1.
# Hermes Agent is configured to use that local endpoint so no upstream API key
# is required.  model.api_key is set to a non-empty dummy because the OpenAI
# client library rejects an empty string before the request reaches Ollama
# (which ignores the key entirely).
#
# Model: nous-hermes3:8b (pulled directly from Ollama Hub via loadModels).
# num_ctx is set to 65536 (64K) via ollama_num_ctx in Hermes settings.
# This satisfies Hermes Agent's 64K minimum requirement while keeping VRAM
# usage well within the RTX 3070's 8GB.
# qwen2.5:7b was previously used; nous-hermes3:8b is a drop-in swap with the
# same context budget and comparable VRAM footprint.
#
# The systemd service runs as the "hermes" system user under /var/lib/hermes.
# addToSystemPackages = true puts the `hermes` CLI on the system PATH and
# exports HERMES_HOME=/var/lib/hermes/.hermes system-wide so interactive shells
# share state with the gateway service.
#
# /var/lib/hermes is created with mode 2770 (hermes:hermes).  bosko must be in
# the hermes group so the interactive CLI can stat/read the .env file inside it
# without hitting EPERM (Python's pathlib.Path.exists() raises on permission
# denied rather than returning False).
{
  hardware.nvidia-container-toolkit.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    loadModels = [ "nous-hermes3:8b" ];
  };

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    settings = {
      model = {
        provider = "custom";
        default = "nous-hermes3:8b";
        base_url = "http://localhost:11434/v1";
        # Non-empty dummy — the OpenAI client requires a non-empty api_key
        # field; Ollama ignores its value.
        api_key = "ollama";
        api_mode = "chat_completions";
        # Pass num_ctx 65536 with every inference request so Ollama allocates
        # the full context window.  Satisfies Hermes Agent's 64K minimum.
        ollama_num_ctx = 65536;
        # Tell Hermes the effective context length for prompt-budget calculations.
        context_length = 65536;
      };
    };
  };

  # Grant bosko read/write access to /var/lib/hermes so the interactive `hermes`
  # CLI (which inherits HERMES_HOME=/var/lib/hermes/.hermes) can traverse the
  # service state directory.  The hermes group is only created on gaming by the
  # module above, so this lives here rather than in the shared users.nix.
  users.users.bosko.extraGroups = [ "hermes" ];
}
