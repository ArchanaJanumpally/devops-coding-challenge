variable "stage" {
  type        = string
  description = "The stage of the build"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "A list of availability zones for the subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "name" {
  type        = string
  description = "The name of the microservice"
}

variable "target_group_name" {
  type        = string
  description = "When given, overrides the name of the target group"
  default     = null
}

variable "container_port" {
  type        = number
  description = "The port the service in the container is listening on"
  default     = 8080
}

variable "path" {
  type        = string
  description = "The HTTP path to the service"
  default     = null
}

variable "health_check_path" {
  type        = string
  description = "The path to check for health"
  default     = null
}

variable "priority" {
  type        = number
  description = "The priority for the listener rule"
  default     = null
}

variable "desired_count" {
  type        = number
  description = "The number of instances to run"
  default     = 1
}

variable "image" {
  type        = string
  description = "The image to run in the container (when null it will use ECR automatically)"
  default     = null
}

variable "memory" {
  type        = number
  description = "The amount of memory to allocate to the container (in GB)"
  default     = 0.5
}

variable "environment" {
  type        = map(string)
  description = "The environment variables to pass to the container"
  default     = {}
}

variable "secrets" {
  type        = map(string)
  description = "The secrets to pass to the container"
  default     = {}
}

variable "port_mappings" {
  type = list(object({
    container_port = number
    host_port      = number
    protocol       = string
  }))
  description = "A list of port mappings"
  default     = []
}

variable "outgoing_tcp_ports" {
  type        = set(number)
  default     = []
  description = "The TCP ports to allow outgoing traffic to"
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "A list of additional security groups for the service"
}

variable "allow_access" {
  type        = list(string)
  default     = []
  description = "A list of security groups to allow access to the service"
}

variable "create_load_balancer" {
  description = "Whether to create a load balancer for the service"
  type        = bool
  default     = true
}

variable "scheduling_strategy" {
  description = "The scheduling strategy for the service"
  type        = string
  default     = "REPLICA"
}

variable "private_registry" {
  description = "Whether to use a private registry"
  type        = bool
  default     = false
}

variable "create_service_discovery" {
  description = "Whether to create a service discovery service"
  type        = bool
  default     = true
}

variable "ec2_asg_instance_type" {
  description = "The instance type for the ECS instances"
  type        = string
  default     = "t2.micro"
  
}

variable "asg_ami_id" {
  description = "The AMI ID for the ECS instances"
  type        = string
  default     = "ami-0b74f796d330ab49c"
  
}