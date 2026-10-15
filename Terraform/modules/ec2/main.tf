module "instances" {
  source = "terraform-aws-modules/ec2-instance/aws"

  for_each = var.instances

  name = "${var.project_name}-${each.key}"

  ami           = each.value.ami
  instance_type = each.value.instance_type
  user_data     = each.value.user_data

  subnet_id = var.private_subnet_ids[each.value.subnet_index]

  associate_public_ip_address = false

  vpc_security_group_ids = var.security_group_ids[each.key]

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Role      = each.key
  }
  create_iam_instance_profile = true

  iam_role_policies = {
    SSM = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  create_security_group = false


}