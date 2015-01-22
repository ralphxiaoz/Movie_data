class MovieData
	# Read in the data from the original ml-100k files and stores them in whichever way it needs to be stored
	# This is a tab separated list of  user id | item id | rating | timestamp.
	# The time stamps are unix seconds since 1/1/1970 UTC
	def load_data
	  file_path = File.dirname(__FILE__) + "/u1.test"
	  f = open(file_path)
	  file_content = f.read.split("\n")
	  f.close
	  return file_content
	end

	# Return a number that indicates the popularity (higher numbers are more popular). 
	# Define popularity: Total points / Days between first & last vote
	# If a movie has only one rating, its popularity is 0
	def popularity(file_content, movie_id)
	  total_rate = 0
	  times = []
	  pop = 0
	  count = 0
	  file_content.each  do |line|
	    string = line.split("\t")
	    if string[1] == movie_id
	      total_rate += string[2].to_i
	      count += 1
	      times.push(string[3].to_i)
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
	def popularity_list(file_content)
	  pop_file_path = File.dirname(__FILE__) + "/popularity_list" # where the list will be stored
	  pop_hash = Hash.new
	  
	  file_content.each do |line|
	    string = line.split("\t")
	    if !pop_hash.has_key?(string[1])
	      pop_hash[string[1]] = popularity(file_content, string[1])
	    end
	  end
	  
	  pop_hash_descend = pop_hash.sort_by {|k, v| v}.reverse
	  
	  f = open(pop_file_path, "w")
	  f.write("Movie#\tPopularity\n")
	  
	  pop_hash_descend.each do |k, v|
	    f.write("\t#{k}\t\t#{v}\n")
	  end
	  
	  f.close
	  
	  puts "Popularity list stored in file #{__FILE__}/popularity_list"
	end

	# Generate a number which indicates the similarity in movie preference between user1 and user2 (where higher numbers indicate greater similarity)
	# Problem: What if u1 & u2 only have 1 film in common?
	# Solution: Only compare two users with more than 3 movies in common. If less than 3, similarity is 0.
	def similarity(file_content, user1, user2)
	  # user_hah: key: movie_ID. value: rating
	  user1_hsh = Hash.new
	  user2_hsh = Hash.new
	  
	  file_content.each do |line|
	    string = line.split("\t")
	    if string[0] == user1
	      user1_hsh[string[1]] = string[2].to_i
	    elsif string[0] == user2
	      user2_hsh[string[1]] = string[2].to_i
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
	def most_similar(file_content, u)
	  sim_file_path = File.dirname(__FILE__) + "/similarity_list"
	  user_list = []
	  file_content.each do |line|
	    string = line.split("\t")
	    if !user_list.include?(string[0])
	      user_list.push(string[0])
	    end
	  end
	  user_list.delete(u)
	  
	  sim_hash = Hash.new
	  user_list.each do |user|
	    sim_hash[user] = similarity(file_content, u, user)
	  end
	  sim_hash_descend = sim_hash.sort_by{|k, v| v}.reverse
	  
	  f = open(sim_file_path, "w")
	  f.write("Users similar to user##{u} are:\n")
	  f.write("User#\tSimilarity(out of 100%)\n")
	  
	  sim_hash_descend.each do |k, v|
		f.write("\t#{k}\t\t#{v}%\n")
	  end
	  
	  f.close
	  
	end
end

md = MovieData.new
# Load the file
file_content = md.load_data
puts "File loaded."

# Main loop
loop do

  puts "---Options---"
  puts "1. Search movie popularity."
  puts "2. List sorted movie popularity(Descend)."
  puts "3. Calculate user similarity."
  puts "4. Find similar user(s)."
  puts "5. Exit"
  print "Please select option: "
  
  user_input = $stdin.gets.chomp
  case user_input
  when "1"
    print "Please input movie id: "
    movie_id = $stdin.gets.chomp
    print "The popularity of movie ##{movie_id} is ", md.popularity(file_content, movie_id), "\n"
  when "2"
    md.popularity_list(file_content)
  when "3"
    print "Please input first user id: "
    user1_id = $stdin.gets.chomp
    print "Please input second user id: "
    user2_id = $stdin.gets.chomp
    sim = md.similarity(file_content, user1_id, user2_id)
    print "Similarity between user# #{user1_id} and user# #{user2_id} is: #{sim}%\n"
  when "4"
    print "Please user id: "
    user_id = $stdin.gets.chomp
    md.most_similar(file_content, user_id)
  when "5"
    exit(0)
  else
    puts "Invalid input, please try again."
  end 
end
