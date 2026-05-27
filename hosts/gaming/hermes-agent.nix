{ ... }:

# Hermes Agent configured to use the local Ollama instance as its LLM backend.
# Ollama exposes an OpenAI-compatible API at http://localhost:11434/v1 — no
# upstream API key is required.  We set model.api_key to a non-empty dummy so
# the OpenAI client library does not reject the request before it reaches
# Ollama (which ignores the key entirely).
#
# The systemd service runs as the "hermes" system user under /var/lib/hermes.
# addToSystemPackages = true puts the `hermes` CLI on the system PATH and
# exports HERMES_HOME=/var/lib/hermes/.hermes system-wide so interactive shells
# share state with the gateway service.
{
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    settings = {
      model = {
        provider = "custom";
        default = "hermes3:8b";
        base_url = "http://localhost:11434/v1";
        # Non-empty dummy — the OpenAI client requires a non-empty api_key
        # field; Ollama ignores its value.
        api_key = "ollama";
        api_mode = "chat_completions";
      };
    };
  };
}
