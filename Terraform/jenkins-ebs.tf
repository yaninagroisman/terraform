data "aws_subnet" "jenkins" {
  id = module.network.private_subnet_ids[1]
}

resource "aws_volume_attachment" "jenkins_data" {
  device_name = "/dev/sdf"
  volume_id   = var.jenkins_ebs_volume_id
  instance_id = module.ec2.instance_ids["jenkins"]
}
