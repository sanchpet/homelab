variable "cloud_id" {
  description = "Yandex Cloud ID the folder belongs to."
  type        = string
}

variable "name" {
  description = "Folder name."
  type        = string
}

variable "description" {
  description = "Folder description."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Resource labels (key-value)."
  type        = map(string)
  default     = {}
}
