#!/usr/bin/env python3
"""
Enhanced Memory Mapping File Handler with Multi-Type Support
Supports dynamic file type selection based on scan type and GCS repository
"""

import os
import sys
import argparse
import mmap
import logging
import tempfile
import shutil
from pathlib import Path
from typing import List, Dict, Set, Tuple
import json
import random

class MultiTypeMemoryMapper:
    """Enhanced memory mapper with support for multiple scan types and repositories"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.logger = self._setup_logging()
        self.scan_type_patterns = {
            'BINARY_SCAN': ['*.jar', '*.war', '*.ear', '*.zip', '*.aar'],
            'SIGNATURE_SCAN': ['*.tar', '*.tar.gz', '*.tgz', '*.zip'],
            'CONTAINER_SCAN': ['*.tar', '*.docker', '*.img'],
        }
        self.repo_weights = {}
        self.scan_weights = {}
        
    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration"""
        logging.basicConfig(
            level=logging.DEBUG if self.verbose else logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        return logging.getLogger(__name__)
    
    def load_distribution_config(self, scan_config: str = None, repo_config: str = None):
        """Load scan type and repository distribution configuration"""
        if scan_config:
            self.scan_weights = self._parse_config_string(scan_config)
            self.logger.info(f"Loaded scan type distribution: {self.scan_weights}")
        
        if repo_config:
            self.repo_weights = self._parse_config_string(repo_config)
            self.logger.info(f"Loaded repository distribution: {self.repo_weights}")
    
    def _parse_config_string(self, config: str) -> Dict[str, int]:
        """Parse configuration string like 'TYPE1:40,TYPE2:35,TYPE3:25'"""
        weights = {}
        for item in config.split(','):
            if ':' in item:
                key, weight = item.strip().split(':')
                weights[key.strip()] = int(weight)
        return weights
    
    def select_scan_type(self) -> str:
        """Select scan type based on weighted distribution"""
        if not self.scan_weights:
            return 'BINARY_SCAN'
        
        rand_num = random.randint(1, 100)
        cumulative = 0
        
        for scan_type, weight in self.scan_weights.items():
            cumulative += weight
            if rand_num <= cumulative:
                return scan_type
        
        return list(self.scan_weights.keys())[0]
    
    def select_repository(self) -> Tuple[str, str]:
        """Select repository based on weighted distribution"""
        if not self.repo_weights:
            return 'performance_test_bdios', 'SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/'
        
        rand_num = random.randint(1, 100)
        cumulative = 0
        
        for repo_path, weight in self.repo_weights.items():
            cumulative += weight
            if rand_num <= cumulative:
                if '/' in repo_path:
                    parts = repo_path.split('/', 1)
                    return parts[0], parts[1]
                return repo_path, ''
        
        # Fallback to first repository
        first_repo = list(self.repo_weights.keys())[0]
        if '/' in first_repo:
            parts = first_repo.split('/', 1)
            return parts[0], parts[1]
        return first_repo, ''
    
    def get_file_patterns_for_scan_type(self, scan_type: str) -> List[str]:
        """Get file patterns for a specific scan type"""
        return self.scan_type_patterns.get(scan_type, ['*.jar', '*.tar', '*.zip'])
    
    def discover_files_by_type(self, source_dirs: List[str], scan_type: str = None) -> Dict[str, List[Path]]:
        """Discover files categorized by scan type"""
        categorized_files = {
            'BINARY_SCAN': [],
            'SIGNATURE_SCAN': [],
            'CONTAINER_SCAN': []
        }
        
        for source_dir in source_dirs:
            source_path = Path(source_dir)
            if not source_path.exists():
                self.logger.warning(f"Source directory does not exist: {source_dir}")
                continue
            
            # Discover all files
            all_files = []
            if source_path.is_file():
                all_files = [source_path]
            else:
                for pattern_list in self.scan_type_patterns.values():
                    for pattern in pattern_list:
                        all_files.extend(source_path.rglob(pattern))
            
            # Categorize files by scan type
            for file_path in all_files:
                file_categorized = False
                for scan_t, patterns in self.scan_type_patterns.items():
                    for pattern in patterns:
                        if file_path.match(pattern):
                            categorized_files[scan_t].append(file_path)
                            file_categorized = True
                            break
                    if file_categorized:
                        break
        
        # Remove duplicates
        for scan_t in categorized_files:
            categorized_files[scan_t] = list(set(categorized_files[scan_t]))
            
        return categorized_files
    
    def create_balanced_scan_set(self, categorized_files: Dict[str, List[Path]], 
                                total_scans: int = 100) -> List[Tuple[str, Path]]:
        """Create a balanced set of scans based on distribution weights"""
        scan_set = []
        
        if not self.scan_weights:
            # Default equal distribution
            self.scan_weights = {'BINARY_SCAN': 40, 'SIGNATURE_SCAN': 35, 'CONTAINER_SCAN': 25}
        
        for scan_type, weight in self.scan_weights.items():
            num_scans = int(total_scans * weight / 100)
            available_files = categorized_files.get(scan_type, [])
            
            if not available_files:
                self.logger.warning(f"No files available for {scan_type}")
                continue
            
            # Select files for this scan type
            selected_files = []
            for i in range(num_scans):
                if available_files:
                    file_path = random.choice(available_files)
                    selected_files.append((scan_type, file_path))
            
            scan_set.extend(selected_files)
            self.logger.info(f"Selected {len(selected_files)} files for {scan_type}")
        
        # Shuffle the final scan set to mix scan types
        random.shuffle(scan_set)
        return scan_set
    
    def prepare_multi_type_scan_files(self, source_dirs: List[str], dest_dir: str, 
                                     total_scans: int = 100) -> Dict[str, any]:
        """Prepare files for multi-type scanning with memory mapping"""
        dest_path = Path(dest_dir)
        dest_path.mkdir(parents=True, exist_ok=True)
        
        # Discover and categorize files
        categorized_files = self.discover_files_by_type(source_dirs)
        
        # Create balanced scan set
        scan_set = self.create_balanced_scan_set(categorized_files, total_scans)
        
        # Prepare memory-mapped files
        prepared_files = []
        total_size = 0
        
        for i, (scan_type, source_file) in enumerate(scan_set):
            # Create descriptive filename
            dest_filename = f"{scan_type.lower()}_{i:04d}_{source_file.name}"
            dest_file_path = dest_path / dest_filename
            
            try:
                # Create hard link for memory mapping
                os.link(str(source_file), str(dest_file_path))
                file_size = dest_file_path.stat().st_size
                total_size += file_size
                
                prepared_files.append({
                    'scan_type': scan_type,
                    'source': str(source_file),
                    'dest': str(dest_file_path),
                    'size': file_size
                })
                
                self.logger.debug(f"Created memory-mapped link: {dest_file_path} -> {source_file}")
                
            except OSError as e:
                self.logger.error(f"Failed to create link for {source_file}: {e}")
                continue
        
        # Create scan metadata
        metadata = {
            'total_files': len(prepared_files),
            'total_size': total_size,
            'total_size_mb': round(total_size / (1024 * 1024), 2),
            'scan_distribution': {},
            'files': prepared_files
        }
        
        # Calculate actual distribution
        for scan_type in self.scan_type_patterns.keys():
            count = sum(1 for f in prepared_files if f['scan_type'] == scan_type)
            metadata['scan_distribution'][scan_type] = count
        
        # Save metadata
        metadata_file = dest_path / 'scan_metadata.json'
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        self.logger.info(f"Prepared {len(prepared_files)} files for multi-type scanning")
        self.logger.info(f"Total size: {metadata['total_size_mb']} MB")
        self.logger.info(f"Distribution: {metadata['scan_distribution']}")
        
        return metadata

def main():
    parser = argparse.ArgumentParser(description='Enhanced Memory Mapping Handler for Multi-Type Scans')
    parser.add_argument('--source-dirs', nargs='+', required=True,
                       help='Source directories to search for files')
    parser.add_argument('--dest-dir', required=True,
                       help='Destination directory for memory-mapped files')
    parser.add_argument('--total-scans', type=int, default=100,
                       help='Total number of scans to prepare')
    parser.add_argument('--scan-config', 
                       help='Scan type distribution config (e.g., "BINARY_SCAN:40,SIGNATURE_SCAN:35,CONTAINER_SCAN:25")')
    parser.add_argument('--repo-config',
                       help='Repository distribution config')
    parser.add_argument('--scan-type', choices=['BINARY_SCAN', 'SIGNATURE_SCAN', 'CONTAINER_SCAN'],
                       help='Filter for specific scan type only')
    parser.add_argument('--info-only', action='store_true',
                       help='Only show file information without creating links')
    parser.add_argument('--verbose', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    mapper = MultiTypeMemoryMapper(verbose=args.verbose)
    
    # Load distribution configurations
    if args.scan_config:
        mapper.load_distribution_config(scan_config=args.scan_config)
    if args.repo_config:
        mapper.load_distribution_config(repo_config=args.repo_config)
    
    if args.info_only:
        # Just discover and show file information
        categorized_files = mapper.discover_files_by_type(args.source_dirs, args.scan_type)
        
        print("File Discovery Summary:")
        print("=====================")
        total_files = 0
        total_size = 0
        
        for scan_type, files in categorized_files.items():
            if not files:
                continue
                
            type_size = sum(f.stat().st_size for f in files if f.exists())
            total_files += len(files)
            total_size += type_size
            
            print(f"{scan_type}:")
            print(f"  Files: {len(files)}")
            print(f"  Size: {type_size / (1024*1024):.2f} MB")
            
            if args.verbose:
                for file_path in files[:5]:  # Show first 5 files
                    print(f"    - {file_path}")
                if len(files) > 5:
                    print(f"    ... and {len(files) - 5} more files")
            print()
        
        print(f"Total files found: {total_files}")
        print(f"Total size: {total_size / (1024*1024):.2f} MB ({total_size / (1024*1024*1024):.2f} GB)")
        
    else:
        # Prepare files for scanning
        metadata = mapper.prepare_multi_type_scan_files(
            args.source_dirs, 
            args.dest_dir, 
            args.total_scans
        )
        
        print(f"Prepared {metadata['total_files']} files for multi-type scanning")
        print(f"Distribution: {metadata['scan_distribution']}")
        print(f"Metadata saved to: {args.dest_dir}/scan_metadata.json")

if __name__ == '__main__':
    main()