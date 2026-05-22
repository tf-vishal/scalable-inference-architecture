resource "aws_security_group" "bastion" {
    name        = "${var.project_name}-bastion-sg"
    description = "Allow SSH access to bastion host"
    vpc_id      = aws_vpc.main.id

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.home_ip]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-bastion-sg"
    }
}

resource "aws_instance" "bastion" {
    ami                         = data.aws_ami.ubuntu.id       
    instance_type               = var.bastion_instance_type
    key_name                    = aws_key_pair.worker_key.key_name 
    subnet_id                   = aws_subnet.public.id
    vpc_security_group_ids      = [aws_security_group.bastion.id]
    associate_public_ip_address = true

    root_block_device {
        volume_size           = 8        
        volume_type           = "gp3"
        delete_on_termination = true
    }

    tags = {
        Name = "${var.project_name}-bastion"
    }
}