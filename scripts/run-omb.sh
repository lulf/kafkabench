#!/bin/bash
OMB_DIR=$1
DRIVER=$2
WORKLOAD=$3
${OMB_DIR}/bin/benchmark -d ${DRIVER} ${WORKLOAD}
