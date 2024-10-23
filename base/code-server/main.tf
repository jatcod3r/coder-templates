terraform {
    required_providers {
        coder = {
            source = "coder/coder"
        }
    }
}

resource "coder_script" "startup_script" {
    agent_id     = var.agent_id
    display_name = "jupyterlab"
    icon         = "/icon/jupyter.svg"
    script = templatefile("${path.module}/run.sh", {
        PORT : var.port
    })
    run_on_start = true
}

resource "coder_app" "code-server" {
    agent_id = coder_agent.coder.id
    slug = "code-server"
    icon = "/icon/code.svg"
    url = "http://localhost:${var.port}?folder=${var.folder}"
    subdomain = false
    share = "authenticated"

    healthcheck {
        url       = "http://localhost:${var.port}/healthz"
        interval  = 3
        threshold = 10
    }  
}