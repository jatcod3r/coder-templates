terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

module "windows_rdp" {
  source      = "registry.coder.com/modules/windows-rdp/coder"
  version     = "1.0.16"
  count       = data.coder_workspace.me.start_count
  agent_id    = resource.coder_agent.main.id
  resource_id = resource.aws_instance.dev[0].id
}

# Last updated 2023-03-14
# aws ec2 describe-regions | jq -r '[.Regions[].RegionName] | sort'
data "coder_parameter" "region" {
  name         = "region"
  display_name = "Region"
  description  = "The region to deploy the workspace in."
  default      = "us-east-1"
  mutable      = false
  option {
    name  = "Asia Pacific (Tokyo)"
    value = "ap-northeast-1"
    icon  = "/emojis/1f1ef-1f1f5.png"
  }
  option {
    name  = "Asia Pacific (Seoul)"
    value = "ap-northeast-2"
    icon  = "/emojis/1f1f0-1f1f7.png"
  }
  option {
    name  = "Asia Pacific (Osaka-Local)"
    value = "ap-northeast-3"
    icon  = "/emojis/1f1f0-1f1f7.png"
  }
  option {
    name  = "Asia Pacific (Mumbai)"
    value = "ap-south-1"
    icon  = "/emojis/1f1f0-1f1f7.png"
  }
  option {
    name  = "Asia Pacific (Singapore)"
    value = "ap-southeast-1"
    icon  = "/emojis/1f1f0-1f1f7.png"
  }
  option {
    name  = "Asia Pacific (Sydney)"
    value = "ap-southeast-2"
    icon  = "/emojis/1f1f0-1f1f7.png"
  }
  option {
    name  = "Canada (Central)"
    value = "ca-central-1"
    icon  = "/emojis/1f1e8-1f1e6.png"
  }
  option {
    name  = "EU (Frankfurt)"
    value = "eu-central-1"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (Stockholm)"
    value = "eu-north-1"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (Ireland)"
    value = "eu-west-1"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (London)"
    value = "eu-west-2"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (Paris)"
    value = "eu-west-3"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "South America (São Paulo)"
    value = "sa-east-1"
    icon  = "/emojis/1f1e7-1f1f7.png"
  }
  option {
    name  = "US East (N. Virginia)"
    value = "us-east-1"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "US East (Ohio)"
    value = "us-east-2"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "US West (N. California)"
    value = "us-west-1"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "US West (Oregon)"
    value = "us-west-2"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
}

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance type"
  description  = "What instance type should your workspace use?"
  default      = "t3.micro"
  mutable      = false
  option {
    name  = "2 vCPU, 1 GiB RAM"
    value = "t3.micro"
  }
  option {
    name  = "2 vCPU, 2 GiB RAM"
    value = "t3.small"
  }
  option {
    name  = "2 vCPU, 4 GiB RAM"
    value = "t3.medium"
  }
  option {
    name  = "2 vCPU, 8 GiB RAM"
    value = "t3.large"
  }
  option {
    name  = "4 vCPU, 16 GiB RAM"
    value = "t3.xlarge"
  }
  option {
    name  = "8 vCPU, 32 GiB RAM"
    value = "t3.2xlarge"
  }
}

provider "aws" {
  region = data.coder_parameter.region.value
}

data "coder_workspace" "me" {
}
data "coder_workspace_owner" "me" {}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

resource "coder_agent" "main" {
  arch = "amd64"
  auth = "aws-instance-identity"
  os   = "windows"
}

resource "coder_script" "attach_disk" {
  agent_id = coder_agent.main.id
  run_on_start = true
  display_name = "Assign Disk"
  script = <<EOT
# Check if the disk is already initialized and has a partition
$disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' }

if ($disk) {
    # Initialize the disk
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru

    # Create a new partition using the maximum size available
    $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter

    # Format the new partition
    Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "CoderHome" -Confirm:$false
} else {
    # If the disk is already initialized, find the partition
    $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $null -and $_.Size -gt 1GB }
    
    if ($partition) {
        # Assign drive letter Z to the existing partition
        Set-Partition -InputObject $partition -NewDriveLetter Z
    } else {
        Write-Host "No suitable partition found. Please check disk configuration."
        exit 1
    }
}

# Ensure the drive is mounted as Z
if ((Get-PSDrive -Name Z -ErrorAction SilentlyContinue) -eq $null) {
    # If Z is not available, find the next available drive letter
    $availableLetter = 68..90 | ForEach-Object { [char]$_ } | 
        Where-Object { (Get-PSDrive -Name $_ -ErrorAction SilentlyContinue) -eq $null } | 
        Select-Object -First 1

    if ($availableLetter) {
        Set-Partition -InputObject $partition -NewDriveLetter $availableLetter
        Write-Host "Drive mounted as $availableLetter`:\"
    } else {
        Write-Host "No available drive letters found."
        exit 1
    }
} else {
    Write-Host "Drive successfully mounted as Z:\"
}
EOT
}

locals {

  # User data is used to stop/start AWS instances. See:
  # https://github.com/hashicorp/terraform-provider-aws/issues/22

  user_data_start = <<EOT
<powershell>
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
${coder_agent.main.init_script}
</powershell>
<persist>true</persist>
EOT

  user_data_end = <<EOT
<powershell>
shutdown /s
</powershell>
<persist>true</persist>
EOT
}


resource "aws_instance" "dev" {
  count             = data.coder_workspace.me.start_count
  ami               = data.aws_ami.windows.id
  availability_zone = "${data.coder_parameter.region.value}a"
  instance_type     = data.coder_parameter.instance_type.value

  user_data = data.coder_workspace.me.transition == "start" ? local.user_data_start : local.user_data_end
  tags = {
    Name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    Coder_Provisioned = "true"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  default      = "50"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 50
    max = 300
  }
}

resource "aws_ebs_volume" "home" {
  availability_zone = "${data.coder_parameter.region.value}a"
  size              = "${data.coder_parameter.home_disk_size.value}"

  tags = {
    Name = "coder-homedir-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    Coder_Provisioned = "true"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  count       = data.coder_workspace.me.start_count
  device_name = "xvdf"
  volume_id   = aws_ebs_volume.home.id
  instance_id = aws_instance.dev[0].id
}
