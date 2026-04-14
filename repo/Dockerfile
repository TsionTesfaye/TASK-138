FROM swift:5.9

WORKDIR /app

# Copy all source code
COPY . .

# Ensure scripts are executable
RUN chmod +x run_tests.sh scripts/run_tests.sh scripts/lint.sh

# Default: run tests
CMD ["./run_tests.sh"]
