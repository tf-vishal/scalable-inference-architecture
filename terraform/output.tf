output "worker_public_ip" {
    description = "Public IP of the worker VM"
    value = aws_instance.worker.public_ip
}

output "worker_public_dns" {
    description = "Public DNS of the worker VM"
    value = aws_instance.worker.public_dns
}

output "inference_private_ip" {
    description = "Private IP of the inference VM"
    value = aws_instance.inference.private_ip
}

output "api_endpoint" {
    description = "API endpoint for the caller worker"
    value = "http://${aws_instance.worker.public_ip}:3111/v1/chat/completions"
}

output "curl_example" {
  description = "Ready-to-run curl command to test the API"
  value       = <<-EOT
    curl -X POST http://${aws_instance.worker.public_ip}:3111/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{
        "messages": [
          {"role": "user", "content": "What is 2+2 ?"}
        ]
      }'
  EOT
}

output "worker_vm_ssh" {
    description = "SSH command to access the worker VM"
    value = "ssh -i worker-key.pem ubuntu@${aws_instance.worker.public_ip}"
}

output "inference_vm_ssh" {
    description = "SSH command to access the inference VM"
    value = "ssh -i worker-key.pem ubuntu@${aws_instance.inference.private_ip}"
}

output "vpc_id" {
    description = "VPC ID"
    value = aws_vpc.main.id
}

