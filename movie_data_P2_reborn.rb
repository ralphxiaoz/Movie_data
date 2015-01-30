require "#{File.dirname(__FILE__)}/Aux.rb"

class MovieData
	
	def initialize(dir, indicator)
		@dir = dir
		@indicator = indicator
		base_file = File.dirname(__FILE__) + "/#{@dir}/#{@indicator}.base"
		@base_um_hsh = Aux.load_file(base_file, "um")
		@base_mu_hsh = Aux.load_file(base_file, "mu")
	end

	# Return a number that indicates the popularity (higher numbers are more popular). 
	# Define popularity: Total points / Days between first & last vote
	# If a movie has only one rating, its popularity is 0
	def popularity(movie_id)
	  total_rate = 0
	  times = []
	  days = 0

	  @base_mu_hsh[movie_id].each do |u, v|
	  	total_rate += v[0].to_i
	  	times.push(v[1].to_i)
	  end

	  times.sort!
	  days = ((times.last - times.first) / (3600 * 24)).to_f
	  if days != 0
	    return (total_rate.to_f / days).round(2)
	  else
	    return 0
	  end
	end

	# Return a list of all movie_id’s ordered by decreasing popularity
	# Result stored in "./popularity_list"
	def popularity_list
	  pop_file_path = File.dirname(__FILE__) + "/popularity_list"
	  pop_hsh = Hash.new
	  
	  f = open(pop_file_path, "w")

	  @base_mu_hsh.keys.each do |m|
	  	pop_hsh[m] = popularity(m)
	  end

	  pop_hsh_dec = pop_hsh.sort_by{|k, v| v}.reverse
	  pop_hsh_dec.each do |k, v|
	    f.write("#{k}\t#{v}\n")
	  end

	  f.close
	  puts "Popularity list stored in file #{File.dirname(__FILE__)}/popularity_list"
	  return pop_hsh_dec
	end

	# Return similarity of 2 hashes using cosine similarity
	# cosine similarity of vector A, B = (A·B)/(|A||B|)
	# Here, 2 vectors must have at least 3 elements
	def hash_sim(hsh1, hsh2)
		common_keys = hsh1.keys & hsh2.keys

		if common_keys.size < 3
			return 0
		else
			sum = 0
			power_sum_hsh1 = 0
			power_sum_hsh2 = 0
			common_keys.each do |k|
				sum += hsh1[k] * hsh2[k]
				power_sum_hsh1 += hsh1[k] **2
				power_sum_hsh2 += hsh2[k] **2
			end
			return (sum.to_f / Math.sqrt(power_sum_hsh1 * power_sum_hsh2) * 100).round(3)
		end
	end

	# Generate a number which indicates the similarity in movie preference between user1 and user2 (where larger numbers indicate greater similarity)
	# Using cosine similarity
	# Problem: What if u1 & u2 only have 1 film in common?
	# Solution: Only compare two users with more than 3 movies in common. If less than 3, similarity is 0.
	def similarity(user1, user2)
	  user1_hsh = Hash.new
	  user2_hsh = Hash.new

	  @base_um_hsh[user1].each do |k, v|
	  	user1_hsh[k] = v[0].to_i
	  end
	  @base_um_hsh[user2].each do |k, v|
	  	user2_hsh[k] = v[0].to_i
	  end

	  return hash_sim(user1_hsh, user2_hsh)
	end

	# Return a list of users whose tastes are most similar to the tastes of user u
	# u is not in this list
	# The result will be saved to file "./similarity_list" if save argument is set
	def most_similar(u, save = nil)

	  user_list = @base_um_hsh.keys
	  user_list.delete(u)
	  sim_hash = Hash.new
	  
	  user_list.each do |user|
	    sim_hash[user] = similarity(u, user)
	  end
	  sim_hash_dec = sim_hash.sort_by {|k, v| v}.reverse

	  if save == "save"
		sim_file_path = File.dirname(__FILE__) + "/similarity_list"
		f = open(sim_file_path, "w")
		 
		sim_hash_dec.each do |k, v|
			f.write("\t#{k}\t\t#{v}%\n")
		end

		puts "Similarity list stored in file #{__FILE__}/similarity_list"
		f.close
	  end
	  
	  return sim_hash_dec
	end

	# return the rating of a user on a certain movie
	def rating(u ,m)
		if @base_um_hsh[u].has_key?(m)
			return @base_um_hsh[u][m][0]	
		else
			return nil
		end
	end

	# Filter users 98% or more similar to u and return them in an array
	# Lower the shreshould, longer it takes to calculate.
	def top_sim_user(u)
		sim_users = []
		sim_hash_descend = most_similar(u)
		sim_hash_descend.each do |k, v|
			if v.to_f > 98
				sim_users.push(k)
			else
				break
			end
		end
		return sim_users
	end

	# returns a floating point number between 1.0 and 5.0 as an estimate of what user u would rate movie m.
	# Based on sim_users, calculate their rating on m if they watched it.
	# Prediction of u on m is the mean of ratings of the similar users have on m.
	# Some movies may not be able to give prediction because users may not have seen m.
	def predict(u, m, sim_users)
		ratings = []
		sim_users.each do |user|
			rate = rating(user, m)
			if rate != nil
				ratings.push(rate.to_i)
			end
		end
		
		prediction = Aux.array_mean(ratings)
		if prediction.nan?
			return 3
		else
			return prediction
		end
		
	end

	# returns the array of movies that user u has watched
	def movies(u)
		return @base_um_hsh[u].keys
	end

	# returns the array of users that have seen movie m
	def viewers(m)
		return @base_mu_hsh[m].keys
	end

	# run the test
	# rows specifies how many rows in the test file to run
	def run_test(rows = nil)

		mt = MovieTest.new(@dir, @indicator, rows)

		mt.test
		puts "Mean: #{mt.mean}"
		puts "Standard diviation: #{mt.stddev}"
		puts "Root-mean-square-error: #{mt.rms}"
	end
end

class MovieTest
	
	def initialize(dir, indicator, rows = nil)
		@tf_lines = []
		@errors = []
		@result = []
		@error_mean = 0
		test_file = File.dirname(__FILE__) + "/#{dir}/#{indicator}.test"
		@test_um_hsh = Aux.load_file(test_file, "um", rows)
		@md_test = MovieData.new(dir, indicator)
		puts "Base file for testing loaded."
	end

	# Predicting the rating of a user in test set based on the base set.
	# For each iterate, will have to go over the whole base file at least once.
	# Return result array in form of [user, movie, rating, prediction]
	# Result stored into file ./result
	def test
		sim_users = []
		time_start = 0
		time_end = 0
		print "Test started at #{time_start = Time.now}. This might take a while.\n"

		@test_um_hsh.each do |u, mhash|
			sim_users = @md_test.top_sim_user(u)
			mhash.each do |m, v|
				print "."
				@result.push([u, m, v[0], @md_test.predict(u, m, sim_users)])
			end
		end
		puts "\nTest termintated at #{time_end = Time.now}."
		puts "Took #{((time_end - time_start).to_f/60).round(2)} minutes."
		return @result
	end

	# returns the average predication error
	def mean
		@result.each do |r|
			@errors.push((r[2].to_f - r[3].to_f).abs)
		end
		@error_mean = Aux.array_mean(@errors)
		return @error_mean
	end

	# returns the standard deviation of the error
	def stddev
		dev = []
		@result.each do |r|
			dev.push(((r[2].to_f - r[3].to_f).abs - @error_mean) **2)
		end
		return Math.sqrt(Aux.array_mean(dev)).round(2)
	end

	# returns the root mean square error of the prediction
	def rms
		error_power = []
		@errors.each do |err|
			error_power.push(err **2)
		end
		return Aux.array_mean(error_power)
	end

	# returns an array of the predictions in the form [u,m,r,p].
	def to_a
		return @result
	end
end

md = MovieData.new("ml-100k", "u1")

# Main loop
loop do

  puts "\n---Options---"
  puts "1. Search movie popularity."
  puts "2. List sorted movie popularity(Descend)."
  puts "3. Calculate user similarity."
  puts "4. Find similar user(s)."
  puts "5. Find movie rating of a user."
  puts "6. Rating prediction."
  puts "7. Watched list of a user."
  puts "8. Viewed list of a movie."
  puts "9. Run Test."
  puts "0. Exit"
  print "Please select option: "
  
  user_input = $stdin.gets.chomp
  case user_input
  when "1"
    print "Input movie id: "
    movie_id = $stdin.gets.chomp
    print "The popularity of movie##{movie_id} is #{md.popularity(movie_id)}\n"
  when "2"
    md.popularity_list
  when "3"
    print "Input first user id: "
    user1_id = $stdin.gets.chomp
    print "Input second user id: "
    user2_id = $stdin.gets.chomp
    sim = md.similarity(user1_id, user2_id)
    puts "Similarity between user# #{user1_id} and user# #{user2_id} is: #{sim}%\n"
  when "4"
    print "Input user id: "
    user_id = $stdin.gets.chomp
    md.most_similar(user_id, "save")
  when "5"
  	print "Input user id: "
  	user_id = $stdin.gets.chomp
  	print "Input movie id: "
  	movie_id = $stdin.gets.chomp
  	rating = md.rating(user_id, movie_id)
  	if rating != 0
  		puts "Movie##{movie_id} is rated #{rating} by user##{user_id}"
  	else
  		puts "User##{user_id} didn't rate this movie."
  	end
  when "6"
  	print "Input user id: "
  	user_id = $stdin.gets.chomp
  	print "Input movie id: "
  	movie_id = $stdin.gets.chomp
  	puts md.predict(user_id, movie_id, md.top_sim_user(user_id))
  when "7"
  	print "Input user id: "
  	user_id = $stdin.gets.chomp
  	puts "User##{user_id} watched movies: #{md.movies(user_id)}"
  when "8"
  	print "Input movie id: "
  	movie_id = $stdin.gets.chomp
  	puts "Users that viewed movie##{movie_id} are: #{md.viewers(movie_id)}"
  when "9"
  	print "Input number of rows to test(default: all):"
  	num = Integer(gets) rescue nil
	md.run_test(num)
  when "0"
    exit(0)
  else
    puts "Invalid input, please try again."
  end 
end