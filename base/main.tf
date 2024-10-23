terraform {
    required_providers {
        coder = {
            source = "coder/coder"
        }
        kubernetes = {
            source = "hashicorp/kubernetes"
        }
    }
}

provider "kubernetes" {
    config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "coder" {
    os = "linux"
    arch = "amd64"
    dir = "/home/coder"
    startup_script_behavior = "blocking"

    display_apps {
      vscode = false
      vscode_insiders = false
      web_terminal = true
      ssh_helper = true
      port_forwarding_helper = true
    }
}

module "jupyterlab" {
  source   = "registry.coder.com/modules/jupyterlab/coder"
  version  = "1.0.19"
  agent_id = coder_agent.coder.id
  share = "owner"
}

# module "vscode-web" {
#   source         = "registry.coder.com/modules/vscode-web/coder"
#   version        = "1.0.20"
#   agent_id       = coder_agent.coder.id
#   accept_license = true
#   share = "owner"
# }

module "code-server" {
  source   = "registry.coder.com/modules/code-server/coder"
  version  = "1.0.18"
  agent_id = coder_agent.coder.id
  share = "owner"
}

# module "code-server-local" {
#   source   = "./code-server"
#   agent_id = coder_agent.coder.id
#   share = "owner"
# }

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home-directory
  ]  
  metadata {
    name = lower("coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}")
    namespace = var.workspaces_namespace
  }
  spec {
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }    
    container {
      name    = "coder-container"
      image   = "codercom/enterprise-base:ubuntu"
      image_pull_policy = "Always"
      command = ["sh", "-c", coder_agent.coder.init_script]
      security_context {
        run_as_user = "1000"
      }      
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.coder.token
      }  
      resources {
        requests = {
          cpu    = "250m"
          memory = "500Mi"
        }        
        limits = {
          cpu    = "2"
          memory = "4G"
        }
      }                       
      volume_mount {
        mount_path = "/home/coder"
        name       = "home-directory"
      }      
    }
    volume {
      name = "home-directory"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home-directory.metadata.0.name
      }
    }        
  }
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = lower("home-coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}")
    namespace = var.workspaces_namespace
  }
  wait_until_bound = false    
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}