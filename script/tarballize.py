import tarfile
import os.path
import argparse

def get_arguments():
    parser = argparse.ArgumentParser(prog='tarballize', description='Turn a directory into a gzipped tarball')
    parser.add_argument('source_directory')
    parser.add_argument('output_filename')
    return parser.parse_args()

def make_tarfile(output_filename, source_dir):
    with tarfile.open(output_filename, "w:gz") as tar:
        tar.add(source_dir, arcname=os.path.basename(source_dir))

if __name__ == "__main__":
    args = get_arguments()
    make_tarfile(args.output_filename, args.source_directory)
