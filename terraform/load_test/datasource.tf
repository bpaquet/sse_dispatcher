data "terraform_remote_state" "local" {
  backend = "local"

  config = {
    path = "../terraform.tfstate"
  }
}

data "aws_subnet" "first_private" {
  id = data.terraform_remote_state.local.outputs.private_subnets[0]
}

data "aws_subnet" "first_public" {
  id = data.terraform_remote_state.local.outputs.public_subnets[0]
}
