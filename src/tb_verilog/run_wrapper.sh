#!/bin/bash
ncverilog +access+r test_wrapper.sv PipelineCtrl.v PipelineTb.v ../Rsa256Wrapper.sv ../Rsa256Core.sv
