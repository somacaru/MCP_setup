#!/bin/bash

echo "Testing Echo MCP Server"
echo "======================"

# Test 1: List tools
echo -e "\n1. Listing available tools:"
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | python echo_server.py | jq '.result.tools[].name'

# Test 2: Call echo_tool
echo -e "\n2. Calling echo_tool with message:"
echo '{"jsonrpc":"2.0","method":"tools/call","id":2,"params":{"name":"echo_tool","arguments":{"message":"Hello from CLI test!"}}}' | python echo_server.py | jq '.result.content[0].text'

# Test 3: List resources
echo -e "\n3. Listing available resources:"
echo '{"jsonrpc":"2.0","method":"resources/list","id":3}' | python echo_server.py | jq '.result.resources'

# Test 4: Read a resource
echo -e "\n4. Reading echo resource:"
echo '{"jsonrpc":"2.0","method":"resources/read","id":4,"params":{"uri":"echo://testing-resources"}}' | python echo_server.py | jq '.result.contents[0].text'

echo -e "\nAll tests completed!"
