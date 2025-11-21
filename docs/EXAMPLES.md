# Examples and Use Cases

## Example 1: ML Training with Spot Instances

### Scenario
Train a machine learning model using PyTorch on spot instances with automatic checkpointing.

### Configuration

**Deployment YAML:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ml-training-job
  namespace: default
spec:
  backoffLimit: 10  # Retry on spot eviction
  template:
    metadata:
      labels:
        app: ml-training
    spec:
      restartPolicy: OnFailure
      tolerations:
      - key: kubernetes.azure.com/scalesetpriority
        operator: Equal
        value: spot
        effect: NoSchedule
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: kubernetes.azure.com/scalesetpriority
                operator: In
                values:
                - spot
      containers:
      - name: pytorch-trainer
        image: pytorch/pytorch:2.0.0-cuda11.7-cudnn8-runtime
        command: ["/bin/bash"]
        args:
          - -c
          - |
            # Install dependencies
            pip install -q transformers datasets tensorboard
            
            # Training script with checkpointing
            python - <<EOF
            import torch
            import os
            from transformers import AutoModelForSequenceClassification, Trainer, TrainingArguments
            
            # Load checkpoint if exists
            checkpoint_dir = "/workspace/checkpoints"
            os.makedirs(checkpoint_dir, exist_ok=True)
            
            model = AutoModelForSequenceClassification.from_pretrained("bert-base-uncased", num_labels=2)
            
            training_args = TrainingArguments(
                output_dir=checkpoint_dir,
                save_strategy="steps",
                save_steps=100,
                save_total_limit=3,
                resume_from_checkpoint=True,
                logging_steps=10,
            )
            
            # Start/resume training
            trainer = Trainer(
                model=model,
                args=training_args,
            )
            
            trainer.train()
            EOF
        resources:
          requests:
            nvidia.com/gpu: 1
          limits:
            nvidia.com/gpu: 1
        volumeMounts:
        - name: workspace
          mountPath: /workspace
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: ml-training-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ml-training-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: managed-premium
  resources:
    requests:
      storage: 100Gi
```

### Expected Cost Savings
- On-Demand: ~$3.06/hr × 10 hours = $30.60
- Spot: ~$0.31/hr × 10 hours = $3.10
- **Savings: $27.50 (90%)**

## Example 2: Production Inference with High Availability

### Scenario
Deploy a GPU-accelerated inference service with high availability using on-demand nodes.

### Configuration

**Deployment YAML:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-inference-service
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: gpu-inference
  template:
    metadata:
      labels:
        app: gpu-inference
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: priority
                operator: In
                values:
                - on-demand
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: gpu-inference
              topologyKey: kubernetes.io/hostname
      containers:
      - name: inference-server
        image: nvcr.io/nvidia/tritonserver:23.04-py3
        args:
          - tritonserver
          - --model-repository=/models
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 8001
          name: grpc
        - containerPort: 8002
          name: metrics
        resources:
          requests:
            nvidia.com/gpu: 1
            memory: 8Gi
            cpu: 4
          limits:
            nvidia.com/gpu: 1
            memory: 8Gi
        livenessProbe:
          httpGet:
            path: /v2/health/live
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /v2/health/ready
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        volumeMounts:
        - name: models
          mountPath: /models
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: models-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: gpu-inference-service
spec:
  selector:
    app: gpu-inference
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  - name: grpc
    port: 8001
    targetPort: 8001
  type: LoadBalancer
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gpu-inference-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gpu-inference-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Example 3: Mixed Workload Strategy

### Scenario
Run both training (spot) and inference (on-demand) workloads in the same cluster.

### Configuration

**Priority Classes:**
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: gpu-critical
value: 1000
globalDefault: false
description: "Critical GPU workloads that require on-demand nodes"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: gpu-training
value: 100
globalDefault: false
description: "Training workloads that can use spot instances"
```

**Training Job (Spot):**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: training-job
spec:
  template:
    spec:
      priorityClassName: gpu-training
      tolerations:
      - key: kubernetes.azure.com/scalesetpriority
        operator: Equal
        value: spot
        effect: NoSchedule
      containers:
      - name: trainer
        image: my-training-image:latest
        resources:
          limits:
            nvidia.com/gpu: 1
```

**Inference Service (On-Demand):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inference-service
spec:
  template:
    spec:
      priorityClassName: gpu-critical
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: priority
                operator: In
                values:
                - on-demand
      containers:
      - name: inference
        image: my-inference-image:latest
        resources:
          limits:
            nvidia.com/gpu: 1
```

## Example 4: Scheduled Batch Processing

### Scenario
Run GPU batch jobs during off-peak hours for maximum cost savings.

### Configuration

**CronJob:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-batch-job
spec:
  schedule: "0 2 * * *"  # Run at 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          tolerations:
          - key: kubernetes.azure.com/scalesetpriority
            operator: Equal
            value: spot
            effect: NoSchedule
          containers:
          - name: batch-processor
            image: my-batch-processor:latest
            resources:
              limits:
                nvidia.com/gpu: 1
            env:
            - name: BATCH_SIZE
              value: "1000"
```

## Example 5: Development Environment

### Scenario
Provide developers with on-demand GPU access for experimentation.

### Configuration

**Namespace with Resource Quota:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev-team
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
  namespace: dev-team
spec:
  hard:
    requests.nvidia.com/gpu: "2"
    limits.nvidia.com/gpu: "2"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: gpu-limit-range
  namespace: dev-team
spec:
  limits:
  - max:
      nvidia.com/gpu: "1"
    type: Container
```

**Jupyter Notebook with GPU:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jupyter-gpu
  namespace: dev-team
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jupyter
  template:
    metadata:
      labels:
        app: jupyter
    spec:
      tolerations:
      - key: kubernetes.azure.com/scalesetpriority
        operator: Equal
        value: spot
        effect: NoSchedule
      containers:
      - name: jupyter
        image: jupyter/tensorflow-notebook:latest
        ports:
        - containerPort: 8888
        resources:
          limits:
            nvidia.com/gpu: 1
        env:
        - name: JUPYTER_ENABLE_LAB
          value: "yes"
---
apiVersion: v1
kind: Service
metadata:
  name: jupyter-gpu
  namespace: dev-team
spec:
  selector:
    app: jupyter
  ports:
  - port: 8888
    targetPort: 8888
  type: LoadBalancer
```

## Example 6: Distributed Training

### Scenario
Run distributed PyTorch training across multiple GPU nodes.

### Configuration

**PyTorch Distributed Job:**
```yaml
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: distributed-training
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      template:
        spec:
          tolerations:
          - key: kubernetes.azure.com/scalesetpriority
            operator: Equal
            value: spot
            effect: NoSchedule
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.0.0-cuda11.7-cudnn8-runtime
            resources:
              limits:
                nvidia.com/gpu: 1
    Worker:
      replicas: 4
      template:
        spec:
          tolerations:
          - key: kubernetes.azure.com/scalesetpriority
            operator: Equal
            value: spot
            effect: NoSchedule
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.0.0-cuda11.7-cudnn8-runtime
            resources:
              limits:
                nvidia.com/gpu: 1
```

## Cost Comparison Table

| Use Case | Node Type | Hours/Month | Cost/Month | Savings |
|----------|-----------|-------------|------------|---------|
| ML Training (24/7) | On-Demand | 730 | $2,234 | - |
| ML Training (24/7) | Spot | 730 | $226 | 90% |
| Dev Environment (40 hrs/week) | Spot | 160 | $50 | 90% |
| Production Inference (3 nodes, 24/7) | On-Demand | 2,190 | $6,701 | - |
| Mixed (2 spot + 1 on-demand) | Mixed | 2,190 | $2,686 | 60% |

## Best Practices from Examples

1. **Always implement checkpointing** for spot instances
2. **Use PersistentVolumeClaims** to survive pod restarts
3. **Set appropriate resource limits** to prevent over-provisioning
4. **Use PriorityClasses** to manage workload importance
5. **Implement health checks** for production workloads
6. **Use HPA** for automatic scaling based on load
7. **Schedule batch jobs** during off-peak hours
8. **Apply resource quotas** per namespace/team

## Additional Resources

- [Kubernetes GPU Scheduling](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)
- [PyTorch Distributed Training](https://pytorch.org/tutorials/beginner/dist_overview.html)
- [NVIDIA Triton Server](https://github.com/triton-inference-server/server)
- [Kubeflow for ML](https://www.kubeflow.org/)
