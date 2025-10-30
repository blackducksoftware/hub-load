#!/usr/bin/env python3
"""
Memory-mapped file handler for efficient access to large test data files.
Provides file access without copying data, using OS-level memory mapping.
"""

import mmap
import os
import sys
import tempfile
import shutil
from pathlib import Path
import argparse
import logging

class MMapFileHandler:
    def __init__(self):
        self.mapped_files = {}
        self.temp_links = []
        
    def create_memory_mapped_link(self, source_path, dest_dir, filename=None):
        """
        Create a memory-mapped access to a file without copying data.
        Creates a hard link or symlink to avoid data duplication.
        """
        source_path = Path(source_path)
        dest_dir = Path(dest_dir)
        
        if not source_path.exists():
            raise FileNotFoundError(f"Source file not found: {source_path}")
            
        # Create destination directory if it doesn't exist
        dest_dir.mkdir(parents=True, exist_ok=True)
        
        # Use original filename if not specified
        if filename is None:
            filename = source_path.name
            
        dest_path = dest_dir / filename
        
        try:
            # Try hard link first (most efficient)
            os.link(source_path, dest_path)
            link_type = "hard"
        except (OSError, FileExistsError):
            try:
                # Fall back to symbolic link
                os.symlink(source_path, dest_path)
                link_type = "symbolic"
            except OSError:
                # Last resort: copy file (but log warning)
                shutil.copy2(source_path, dest_path)
                link_type = "copy"
                logging.warning(f"Had to copy file {source_path} to {dest_path}")
        
        self.temp_links.append(dest_path)
        logging.info(f"Created {link_type} link: {dest_path} -> {source_path}")
        return str(dest_path)
    
    def memory_map_file(self, file_path, mode='r'):
        """
        Memory map a file for efficient access.
        Returns a memory-mapped file object.
        """
        file_path = str(file_path)
        if file_path in self.mapped_files:
            return self.mapped_files[file_path]
            
        try:
            # Open file in binary mode for mmap
            file_obj = open(file_path, 'rb')
            
            # Create memory map
            if os.path.getsize(file_path) > 0:
                mmap_obj = mmap.mmap(file_obj.fileno(), 0, access=mmap.ACCESS_READ)
                self.mapped_files[file_path] = {
                    'file': file_obj,
                    'mmap': mmap_obj,
                    'size': os.path.getsize(file_path)
                }
                logging.info(f"Memory mapped file: {file_path} ({self.mapped_files[file_path]['size']} bytes)")
                return self.mapped_files[file_path]
            else:
                file_obj.close()
                raise ValueError(f"File is empty: {file_path}")
                
        except Exception as e:
            logging.error(f"Failed to memory map {file_path}: {e}")
            if 'file_obj' in locals():
                file_obj.close()
            return None
    
    def get_file_info(self, file_path):
        """Get information about a file without fully loading it."""
        file_path = Path(file_path)
        if not file_path.exists():
            return None
            
        stat = file_path.stat()
        return {
            'path': str(file_path),
            'size': stat.st_size,
            'size_mb': round(stat.st_size / (1024 * 1024), 2),
            'size_gb': round(stat.st_size / (1024 * 1024 * 1024), 2),
            'modified': stat.st_mtime,
            'accessible': os.access(file_path, os.R_OK)
        }
    
    def prepare_scan_files(self, source_files, dest_dir, max_files=None):
        """
        Prepare multiple files for scanning using memory mapping approach.
        Creates efficient links without copying data.
        """
        dest_dir = Path(dest_dir)
        prepared_files = []
        
        files_to_process = source_files[:max_files] if max_files else source_files
        
        for source_file in files_to_process:
            try:
                dest_file = self.create_memory_mapped_link(source_file, dest_dir)
                file_info = self.get_file_info(dest_file)
                if file_info:
                    prepared_files.append({
                        'source': str(source_file),
                        'dest': dest_file,
                        'size_mb': file_info['size_mb']
                    })
            except Exception as e:
                logging.error(f"Failed to prepare file {source_file}: {e}")
                
        total_size_mb = sum(f['size_mb'] for f in prepared_files)
        logging.info(f"Prepared {len(prepared_files)} files, total size: {total_size_mb:.2f} MB")
        
        return prepared_files
    
    def cleanup(self):
        """Clean up memory mapped files and temporary links."""
        # Close memory mapped files
        for file_path, mmap_info in self.mapped_files.items():
            try:
                mmap_info['mmap'].close()
                mmap_info['file'].close()
                logging.info(f"Closed memory map for: {file_path}")
            except Exception as e:
                logging.error(f"Error closing memory map for {file_path}: {e}")
        
        # Remove temporary links
        for temp_link in self.temp_links:
            try:
                if temp_link.exists():
                    temp_link.unlink()
                    logging.info(f"Removed temporary link: {temp_link}")
            except Exception as e:
                logging.error(f"Error removing temporary link {temp_link}: {e}")
        
        self.mapped_files.clear()
        self.temp_links.clear()

def main():
    parser = argparse.ArgumentParser(description='Memory-mapped file handler for efficient file access')
    parser.add_argument('--source-files', nargs='+', required=True, help='Source files to process')
    parser.add_argument('--dest-dir', required=True, help='Destination directory')
    parser.add_argument('--max-files', type=int, help='Maximum number of files to process')
    parser.add_argument('--info-only', action='store_true', help='Only show file information')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.INFO if args.verbose else logging.WARNING
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    handler = MMapFileHandler()
    
    try:
        if args.info_only:
            # Just show file information
            for source_file in args.source_files:
                info = handler.get_file_info(source_file)
                if info:
                    print(f"File: {info['path']}")
                    print(f"  Size: {info['size_mb']:.2f} MB ({info['size_gb']:.2f} GB)")
                    print(f"  Accessible: {info['accessible']}")
                else:
                    print(f"File not found or inaccessible: {source_file}")
        else:
            # Prepare files for scanning
            prepared_files = handler.prepare_scan_files(
                args.source_files, 
                args.dest_dir, 
                args.max_files
            )
            
            # Output the prepared file paths (for bash script to use)
            for file_info in prepared_files:
                print(file_info['dest'])
                
    except KeyboardInterrupt:
        logging.info("Interrupted by user")
    except Exception as e:
        logging.error(f"Error: {e}")
        sys.exit(1)
    finally:
        handler.cleanup()

if __name__ == '__main__':
    main()