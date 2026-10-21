resource "aws_volume_attachment" "gitlab_data" {
  device_name = "/dev/sdf"
  volume_id   = var.gitlab_ebs_volume_id
  instance_id = module.ec2.instance_ids["gitlab"]

  # Stop the instance before detaching, so destroy does not hang on a mounted volume
  stop_instance_before_detaching = true
}
