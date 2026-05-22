data "aws_ami" "ubuntu" {
    most_recent = true
    owners      = ["099720109477"]

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_key_pair" "worker_key" {
    key_name   = var.key_name
    public_key = file("${path.module}/worker-key.pub")
}

resource "aws_instance" "worker" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = "${var.worker_instance_type}"
    key_name      = aws_key_pair.worker_key.key_name
    subnet_id = aws_subnet.public.id
    vpc_security_group_ids = [aws_security_group.worker.id]
    associate_public_ip_address = true
    user_data = templatefile("${path.module}/scripts/worker.sh", {
        http_port = var.http_port
        ws_port   = var.ws_port
    })

    root_block_device {
        volume_size = 20
        volume_type = "gp3"
        delete_on_termination = true
    }

    tags = {
        Name = "${var.project_name}-worker"
    }
}

resource "aws_instance" "inference" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = "${var.instance_type_inference}"
    key_name      = aws_key_pair.worker_key.key_name
    subnet_id = aws_subnet.private.id
    vpc_security_group_ids = [aws_security_group.inference.id]
    associate_public_ip_address = false
    user_data = templatefile("${path.module}/scripts/inference.sh", {
        worker_private_ip = aws_instance.worker.private_ip
        ws_port           = var.ws_port
    })
    depends_on = [aws_instance.worker]

    root_block_device {
        volume_size = 20
        volume_type = "gp3"
        delete_on_termination = true
    }

    tags = {
        Name = "${var.project_name}-inference"
    }
}