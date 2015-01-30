require "csv"
module Aux
	
	# load the file, format depending on relation
	# um(user-movie) relation: load the file into um_hsh -- {user => {movie => [rating, time]}} 
	# mu(movie-user) relation: load the file into mu_hsh -- {movie => {user => [rating, time]}} 
	# is there any better way to generate such a hash?
 	def Aux.load_file(file_path, relation, rows = nil)
		um_hsh = {}
		mu_hsh = {}
		count = 0
		CSV.foreach(file_path, {:col_sep => "\t"}) do |line|
			if rows != nil && count > rows.to_i
				break
			end
			if um_hsh.has_key?(line[0])
				um_hsh[line[0]][line[1]] = [line[2], line[3]]
			else
				um_hsh[line[0]] = {line[1] => [line[2], line[3]]}
			end
			if mu_hsh.has_key?(line[1])
				mu_hsh[line[1]][line[0]] = [line[2], line[3]]
			else
				mu_hsh[line[1]] = {line[0] => [line[2], line[3]]}
			end
			count += 1
		end

		if relation == "um"
			return um_hsh
		elsif relation == "mu"
			return mu_hsh
		else
			print "Wrong relation arg in load_file."
		end
	end

	# return the mean of an array
	def Aux.array_mean(arr)
		return (arr.inject{ |sum, el| sum + el }.to_f / arr.size).round(2)
	end

end