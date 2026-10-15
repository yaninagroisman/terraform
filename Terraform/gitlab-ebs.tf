resource "aws_volume_attachment" "gitlab_data" {
  device_name = "/dev/sdf"
  volume_id   = "vol-080b5bce97f8f814b"
  instance_id = module.ec2.instance_ids["gitlab"]

  stop_instance_before_detaching = true
}