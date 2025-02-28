from pathlib import Path
import csv
import datetime

# Relative paths to neccessry folders
abricate_folder = Path('.') / '..' / 'abricate' 
fasta_folder = Path('.') / '..' / 'genomes_skesa_job'

class Gene():
	def fasta_header(self):
		return f'>{self.file.split("_")[0]}_{self.sequence}\n'
		
	def __repr__(self):
		return f'{self.name} {self.file} {self.sequence} {self.contig[:10]}...'
		

class GeneLookupEntry():
	def __init__(self):
		self.file = None
		self.sequence = None
		
	def open(self):
		return open(fasta_folder / self.file, 'r')
	
	def check_duplicate(self, other):
		return self.file == other.file and self.sequence == other.sequence
		
	def __repr__(self):
		return f'{self.name} {self.file}'
		
	def __lt__(self, other):
		if self.file == other.file:
			return self.sequence < other.sequence
			
		return self.file < other.file
		
def read_abricate(filename):
	with open(filename, newline='') as f:
		reader = csv.DictReader(f, delimiter='\t')
		for row in reader:
			if row['GENE'].startswith('Van'): # Only get these genes
				gene = GeneLookupEntry()
				gene.name = row['GENE']
				gene.file = Path(row['#FILE']).name
				gene.sequence = row['SEQUENCE']
				yield gene
	
def read_wanted_genes():
	print('Reading abricate files...')
	wanted_genes = []
	abricate_files = list(abricate_folder.glob('**/*.*'))
	for filename in abricate_files:
		for gene in read_abricate(filename):
			wanted_genes.append(gene)
	
	return wanted_genes
	
def sort_and_filter_wanted_genes(wanted_genes):
	wanted_genes_sorted = sorted(wanted_genes)
	wanted_genes_filtered = []
	last = GeneLookupEntry()
	for g in wanted_genes_sorted:
		if not g.check_duplicate(last):
			wanted_genes_filtered.append(g)
		last = g
		
	return wanted_genes_filtered

def main():
	print('Start..')
	
	wanted_genes = sort_and_filter_wanted_genes(read_wanted_genes())

	# Create output filename with custom filename
	
	output_filename = f'VRE_contigs.fasta'

	print('Reading fasta files and writing output file..')
	with open(output_filename, 'w') as f_out:
		f = wanted_genes[0].open()
		for g in wanted_genes:
			
			if f.name != g.file:
				f.close()
				f = g.open()
				
			while(1):
				line = f.readline()
				if not line: # End of file
					break
				if line.startswith(f'>{g.sequence}'):
					gene = Gene()
					gene.name = g.name
					gene.contig = f.readline()
					gene.file = g.file
					gene.sequence = g.sequence
					f_out.write(gene.fasta_header())
					f_out.write(gene.contig)
					break
		f.close()
		
	print('Done')
	
if __name__ == '__main__':
	main()
	