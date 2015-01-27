
class MovieData
	
	def initialize(dir, indicator)
		@dir = dir
		@indicator = indicator
		@bf_lines = []
		base_file = File.dirname(__FILE__) + "/#{@dir}/#{@indicator}.base"
		
		bf = open(base_file)
		bf_content = bf.read.split("\n")
		bf_content.each do |line|
			@bf_lines.push(line.split("\t"))
		end
		puts "Base file loaded."
		bf.close
	end

	# Return a number that indicates the popularity (higher numbers are more popular). 
	# Define popularity: Total points / Days between first & last vote
	# If a movie has only one rating, its popularity is 0
	def popularity(movie_id)
	  total_rate = 0
	  times = []
	  pop = 0
	  count = 0

	  @bf_lines.each do |line|
	  	if line[1] == movie_id
	  		total_rate += line[2].to_i
	  		count += 1
	  		times.push(line[3].to_i)
	  	end
	  end
	  
	  times.sort!
	  days_between = (times.last - times.first) / (3600 * 24)
	  
	  if days_between != 0
	    pop = (total_rate.to_f / days_between.to_f)
	  else
	    pop = 0
	  end
	  
	  # puts "total rate for this film is #{total_rate}"
	  # puts "took #{days_between} days to achieve #{count} votes, average rating is #{total_rate/count}"
	  
	  return pop.round(2)
	end

	# Generate a list of all movie_id’s ordered by decreasing popularity
	def popularity_list
	  pop_file_path = File.dirname(__FILE__) + "/popularity_list"
	  pop_hash = Hash.new
	  
	  @bf_lines.each do |line|
	  	if !pop_hash.has_key?(line[1])
	  		pop_hash[line[1]] = popularity(line[1])
	  	end
	  end
	  
	  pop_hash_descend = pop_hash.sort_by {|k, v| v}.reverse
	  
	  f = open(pop_file_path, "w")
	  f.write("Movie#\tPopularity\n")
	  
	  pop_hash_descend.each do |k, v|
	    f.write("\t#{k}\t\t#{v}\n")
	  end
	  
	  f.close
	  puts "Popularity list stored in file #{File.dirname(__FILE__)}/popularity_list"
	  return pop_hash_descend
	end

	# Generate a number which indicates the similarity in movie preference between user1 and user2 (where higher numbers indicate greater similarity)
	# Problem: What if u1 & u2 only have 1 film in common?
	# Solution: Only compare two users with more than 3 movies in common. If less than 3, similarity is 0.
	def similarity(user1, user2)
	  # user_hah: key: movie_ID. value: rating
	  user1_hsh = Hash.new
	  user2_hsh = Hash.new
	  
	  @bf_lines.each do |line|
	  	if line[0] == user1
	      user1_hsh[line[1]] = line[2].to_i
	    elsif line[0] == user2
	      user2_hsh[line[1]] = line[2].to_i
	   	end
	  end
	  
	  common = 0
	  user1_hsh.each do |k, v|
	    if user2_hsh.has_key?(k)
	      common += 1
	    end
	  end
	  
	  if common > 3
	  	sum = 0
	    power_sum_user1 = 0
	    power_sum_user2 = 0
	    user1_hsh.each do |k, v|
	      if user2_hsh.has_key?(k)
	        sum += user1_hsh[k] * user2_hsh[k]
	        power_sum_user1 += user1_hsh[k] **2
	        power_sum_user2 += user2_hsh[k] **2
	      end
	    end
	    sim = (sum.to_f / Math.sqrt(power_sum_user1 * power_sum_user2) * 100).round(3)
	    return sim
	  else
	    return 0
	  end
	end

	# Return a list of users whose tastes are most similar to the tastes of user u
	# The result will be saved to file "./similarity_list"
	def most_similar(u, save)

	  user_list = []
	  
	  @bf_lines.each do |line|
	  	if !user_list.include?(line[0])
	      user_list.push(line[0])
	   	end
	  end

	  user_list.delete(u)
	  
	  sim_hash = Hash.new
	  user_list.each do |user|
	    sim_hash[user] = similarity(u, user)
	  end
	  sim_hash_descend = sim_hash.sort_by{|k, v| v}.reverse
	  
	  if save == "save"
		sim_file_path = File.dirname(__FILE__) + "/similarity_list"
		f = open(sim_file_path, "w")
		f.write("Users similar to user##{u} are:\n")
		f.write("User#\tSimilarity(out of 100%)\n")
		 
		sim_hash_descend.each do |k, v|
			f.write("\t#{k}\t\t#{v}%\n")
		end

		puts "Similarity list stored in file #{__FILE__}/similarity_list"
		f.close
	  end
	  
	  return sim_hash_descend
	end

	def rating(u ,m)
		rate = 0
		@bf_lines.each do |line|
			if line[0] == u && line[1] == m
				rate = line[2]
			end
		end
		return rate
	end

	# Filter users 90% or more similar to u
	def top_sim_user(u)
		sim_users = []
		sim_hash_descend = most_similar(u, "no")
		sim_hash_descend.each do |k, v|
			if v.to_f > 90
				sim_users.push(k)
			else
				break
			end
		end
		return sim_users
	end

	# returns a floating point number between 1.0 and 5.0 as an estimate of what user u would rate movie m.
	# Find users similar to u, calculate their rating on m if they watched it.
	# Some movies may not be able to give prediction.
	# Higher the threshould, fater the calculation.
	def predict(u, m, sim_users)
		ratings = []
		sim_users.each do |user|
			rate = rating(user, m)
			ratings.push(rate.to_i)
		end
		
		sum = 0
		count = 0
		ratings.each do |i|
			if i != 0
				sum += i
				count += 1
			end
		end
		prediction = sum/count.to_f
		return prediction.round(1)
	end

	def movies(u)
		watched_array = []
		@bf_lines.each do |line|
			if line[0] == u && !watched_array.include?(line[1])
				watched_array.push(line[1].to_i)
			end
		end
		return watched_array.sort!
	end

	def viewers(m)
		viewed_array = []
		@bf_lines.each do |line|
			if line[1] == m && !viewed_array.include?(line[0])
				viewed_array.push(line[0].to_i)
			end
		end
		return viewed_array.sort!
	end

	def run_test #(k)

		mt = MovieTest.new(@dir, @indicator)

		mt.test
		puts "Mean: #{mt.mean}"
		puts "Standard diviation: #{mt.stddev}"
		puts "Root-mean-square-error: #{mt.rms}"
	end
end

class MovieTest
	
	def initialize(dir, indicator)
		@tf_lines = []
		test_file = File.dirname(__FILE__) + "/#{dir}/#{indicator}.test"
	
		tf = open(test_file)
		tf_content = tf.read.split("\n")
		tf_content.each do |line|
			@tf_lines.push(line.split("\t"))
		end
		puts "Test file loaded."
		tf.close

		@md_test = MovieData.new(dir, indicator)
		puts "Base file for testing loaded."

		@error_mean

	end

	# Predicting the rating of a user in test set based on the base set.
	# For each iterate, will have to go over the whole base file at least once.
	# Result written into file ~/result
	def test

		if File.exist?(File.dirname(__FILE__) + "/result")
			puts "Test result file exist."
		else
			sim_users = []
			predicted_users = []
			f = open(File.dirname(__FILE__) + "/result", "w")
			f.truncate(0)
			f.close
			time_start = 0
			time_end = 0
			puts "Test started at #{time_start = Time.now}"
			print "Test running."
			@tf_lines.each_with_index do |line, index|
				f = open(File.dirname(__FILE__) + "/result", "a")
				if !predicted_users.include?(line[0])
					# puts Time.now
					sim_users = @md_test.top_sim_user(line[0])
					predicted_users.push(line[0])
				end
				prediction = @md_test.predict(line[0], line[1], sim_users)
				print "."
				f.write("#{line[0]}\t#{line[1]}\t#{line[2]}\t#{prediction}\n")
				f.close
			end
			puts "Test termintated at #{time_end = Time.now}. Took #{((time_end - time_start).to_f/3600).round(2)} hours."
			puts "Result stored in #{__FILE__}/result"
		end
	end

	# load_result loads the test result file generated from test.
	# This could be implemented in to_a but since to_a is part of the test and might not run,
	# while other tests depends on the test result. Thus the loading was implemented separatedly.
	def self.load_result
		test_result = []
		f = open(File.dirname(__FILE__) + "/result", "r")
		file_content = f.read.split("\n")
		file_content.each do |line|
			test_result.push(line.split("\t"))
		end
		puts "Result file loaded."
		return test_result
	end

	# returns the average predication error (which should be close to zero)
	def mean
		error_sum = 0
		count = 0
		test_result = MovieTest.load_result
		test_result.each do |line|
			if line[3] != "NaN"
				error_sum += (line[2].to_f - line[3].to_f).abs
				count += 1
			end
		end
		@error_mean = (error_sum / count).round(2)
		return @error_mean
	end

	# returns the standard deviation of the error
	def stddev
		sum = 0
		count = 0
		test_result = MovieTest.load_result
		test_result.each do |line|
			if line[3] != "NaN"
				sum += ((line[3].to_f - line[2].to_f).abs - @error_mean) **2
				count += 1
			end
		end
		stddev = Math.sqrt(sum/count).round(2)
		return stddev
	end

	# returns the root mean square error of the prediction
	def rms
		sum = 0
		count = 0
		test_result = MovieTest.load_result
		test_result.each do |line|
			if line[3] != "NaN"
				sum += (line[3].to_f - line[2].to_f) **2
				count += 1
			end
		end
		rms = Math.sqrt(sum/count).round(2)
		return rms
	end

	# returns an array of the predictions in the form [u,m,r,p].
	def to_a
		prediction_array = MovieTest.load_result
		return prediction_array
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
    print "The popularity of movie##{movie_id} is ", md.popularity(movie_id), "\n"
  when "2"
    md.popularity_list
  when "3"
    print "Input first user id: "
    user1_id = $stdin.gets.chomp
    print "Input second user id: "
    user2_id = $stdin.gets.chomp
    sim = md.similarity(user1_id, user2_id)
    print "Similarity between user# #{user1_id} and user# #{user2_id} is: #{sim}%\n"
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
  	md.run_test
  when "0"
    exit(0)
  else
    puts "Invalid input, please try again."
  end 
end
