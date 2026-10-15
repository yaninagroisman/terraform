variable "project_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "instances" {
  type = map(object({
    ami           = string
    instance_type = string
    subnet_index  = number
    user_data     = optional(string)
    private_ip    = optional(string)
  }))
}

variable "security_group_ids" {
  type = map(list(string))
}
