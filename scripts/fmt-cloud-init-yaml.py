#!/usr/bin/env python3
"""
~~Hack~~Script to format cloud-init YAML files by temporarily omitting #include
directives and URLs

(yamlfmt doesn't support cloud-init's non-yaml YAML -- BOO cloud-init!)
"""
import sys
import subprocess
import tempfile
import re
from pathlib import Path


def format_yaml_file(file_path: Path) -> None:
    """Format a single YAML file, handling cloud-init #include directives."""
    content = file_path.read_text()
    lines = content.splitlines()

    # Check if file contains #include directives
    if not any(line.strip() == "#include" for line in lines):
        # No #include directives, format normally
        try:
            subprocess.run(
                ["yamlfmt", str(file_path)], check=False, capture_output=True
            )
        except FileNotFoundError:
            print("yamlfmt not found, skipping formatting")
        return

    # Extract #include blocks
    include_blocks = []
    processed_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        if line.strip() == "#include":
            # Check if there was a blank line before #include
            needs_leading_blank = (
                i > 0 and 
                lines[i-1].strip() == ""
            )
            
            # Start of include block
            include_lines = []
            if needs_leading_blank:
                include_lines.append("")
            include_lines.append(line)
            i += 1

            # Collect URLs that follow
            while i < len(lines):
                next_line = lines[i]
                if re.match(r"^\s*https?://", next_line):
                    include_lines.append(next_line)
                    i += 1
                else:
                    break

            # Skip any blank lines immediately after the URLs
            while i < len(lines) and lines[i].strip() == "":
                i += 1

            # Add exactly one blank line after the include block
            include_lines.append("")

            # Store the block and add placeholder
            include_blocks.append(include_lines)
            processed_lines.append("# CLOUD_INIT_INCLUDE_PLACEHOLDER")
        else:
            processed_lines.append(line)
            i += 1

    # Write temp file without #include blocks
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".yaml", delete=False
    ) as temp_file:
        temp_file.write("\n".join(processed_lines))
        temp_path = Path(temp_file.name)

    try:
        # Format the temp file
        try:
            subprocess.run(
                ["yamlfmt", str(temp_path)], check=False, capture_output=True
            )
        except FileNotFoundError:
            print("yamlfmt not found, skipping formatting")

        # Read back the formatted content
        formatted_content = temp_path.read_text()
        formatted_lines = formatted_content.splitlines()

        # Restore #include blocks
        final_lines = []
        block_index = 0

        for line in formatted_lines:
            if line.strip() == "# CLOUD_INIT_INCLUDE_PLACEHOLDER":
                if block_index < len(include_blocks):
                    final_lines.extend(include_blocks[block_index])
                    block_index += 1
            else:
                final_lines.append(line)

        # Normalize excessive blank lines (3+ consecutive newlines -> 2)
        final_content = "\n".join(final_lines) + "\n"
        final_content = re.sub(r'\n{3,}', '\n\n', final_content)
        
        # Write final result
        file_path.write_text(final_content)

    finally:
        # Clean up temp file
        temp_path.unlink(missing_ok=True)


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: format-yaml.py <file1> <file2> ...")
        sys.exit(1)

    for file_arg in sys.argv[1:]:
        file_path = Path(file_arg)
        if file_path.is_file():
            format_yaml_file(file_path)
        else:
            print(f"Warning: {file_path} is not a file, skipping")


if __name__ == "__main__":
    main()
