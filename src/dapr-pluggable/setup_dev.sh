#!/bin/bash

# Development Environment Setup Script
# Run this once after starting dependencies with: docker-compose -f docker-compose.dependencies.yml up -d

echo "🚀 Setting up NebulaGraph development environment..."

# Wait for NebulaGraph to be ready
echo "⏳ Waiting for NebulaGraph cluster to be ready..."
sleep 10

# Initialize NebulaGraph cluster
echo "🔧 Initializing NebulaGraph cluster..."
./init_nebula.sh

# Run component tests
echo "🧪 Running component tests..."
./test_component.sh

echo "✅ Development environment setup complete!"
echo ""
echo "Your NebulaGraph Dapr component is now ready for development."
echo "The dapr_state space has been created and tested."
echo ""
echo "📋 Next Steps:"
echo "• Run tests again: ./test_component.sh"
echo "• Start your component: docker-compose up -d"
echo ""
echo "🔧 Debugging Tools:"
echo "• Console access: docker exec -it nebula-console nebula-console -addr nebula-graphd -port 9669 -u root -p nebula"
echo "• Web interface: docker-compose -f docker-compose.dependencies.yml --profile studio up -d nebula-studio"
echo "• Studio URL: http://localhost:7001 (connect to nebula-graphd:9669 with root/nebula)"
