resource "aws_volume_attachment" "jenkins_data" {
  device_name = "/dev/sdf"
  volume_id   = var.jenkins_ebs_volume_id
  instance_id = module.ec2.instance_ids["jenkins"]

  # Same as GitLab: the volume is mounted at /var/lib/jenkins, a live detach can hang destroy
  stop_instance_before_detaching = true
}
