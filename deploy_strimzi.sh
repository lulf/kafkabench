#!/bin/bash
kubectl create namespace kafka
kubectl config set-context $(kubectl config current-context) --namespace=kafka
kubectl apply -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

