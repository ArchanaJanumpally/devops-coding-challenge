module "crewmeister" {
    source = "./modules/ecs-service"
    name = "crewmeister"
    stage = "dev"
    desired_count = 1
    health_check_path = "/health"
    path = "/crewmeister"
    outgoing_tcp_ports = [ 443 ]  
}