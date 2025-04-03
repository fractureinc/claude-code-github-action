const core = require('@actions/core');
const github = require('@actions/github');
const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const execAsync = promisify(exec);

async function run() {
  try {
    console.log('Starting Claude Code GitHub Action');
    
    const mode = core.getInput('mode', { required: true });
    console.log(`Running in mode: ${mode}`);
    
    // Common parameters
    const version = core.getInput('version') || 'claude-3-opus-20240229';
    const systemPrompt = core.getInput('system-prompt');
    const maxTokens = core.getInput('max-tokens') || '4096';
    const temperature = core.getInput('temperature') || '0.7';
    const rawOutput = core.getInput('raw') === 'true';
    const debug = core.getInput('debug') === 'true';
    const outputFile = core.getInput('output-file');
    const modelProvider = core.getInput('model-provider') || 'anthropic';
    
    // Build claude-cli command based on mode
    let claudeCommand = `claude --model ${version} --max-tokens ${maxTokens} --temperature ${temperature}`;
    
    if (systemPrompt) {
      claudeCommand += ` --system "${systemPrompt}"`;
    }
    
    if (mode === 'pr-comment') {
      const prUrl = core.getInput('pr-url', { required: true });
      console.log(`Processing PR: ${prUrl}`);
      
      // Here you would process PR comments and interact with Claude
      
    } else if (mode === 'comment') {
      const comment = core.getInput('comment', { required: true });
      console.log(`Processing comment: ${comment}`);
      
      // Here you would process GitHub comment and interact with Claude
      
    } else if (mode === 'direct') {
      const request = core.getInput('request', { required: true });
      console.log('Processing direct request');
      
      // Here you would directly send the request to Claude
      
    } else {
      throw new Error(`Unsupported mode: ${mode}`);
    }
    
    console.log('Claude Code GitHub Action completed successfully');
    
  } catch (error) {
    core.setFailed(`Action failed with error: ${error.message}`);
  }
}

run();