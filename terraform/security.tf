resource "aws_security_group" "worker" {
    name        = "${var.project_name}-worker-sg"
    description = "Security group for worker instance"
    vpc_id      = aws_vpc.main.id

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["${var.home_ip}"]
    }



    ingress {
        description = "Allow RPC websocket from inference instance"
        from_port   = var.http_port
        to_port     = var.http_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Allow HTTP from inference instance"
        from_port   = var.ws_port
        to_port     = var.ws_port
        protocol    = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }


    tags = {
        Name = "${var.project_name}-worker-sg"
    }
}

resource "aws_security_group" "inference" {
    name        = "${var.project_name}-inference-sg"
    description = "Security group for inference instance"
    vpc_id      = aws_vpc.main.id

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        security_groups = [aws_security_group.bastion.id]
    }
    ingress {
        from_port       = var.ws_port
        to_port         = var.ws_port
        protocol        = "tcp"
        security_groups = [aws_security_group.worker.id]
    }

    egress {
        description = "Allow outbound internet access"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-inference-sg"
    }
}