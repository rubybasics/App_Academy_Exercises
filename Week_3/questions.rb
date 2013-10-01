require 'singleton'
require 'sqlite3'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super("questions_database.db")

    self.results_as_hash = true
    self.type_translation = true
  end
end

class User

  attr_accessor :user_id, :first, :last

  def initialize(options = {})
    @user_id = options["user_id"]
    @first = options["first"]
    @last = options["last"]
  end

  def User.find_by_id(id_to_find)
    query = %Q[
      SELECT * FROM
        users
      WHERE user_id = #{id_to_find};]
    User.new(QuestionsDatabase.instance.execute(query)[0])
  end

  def User.find_by_name(first, last)
    query = %Q[
      SELECT * FROM
        users
      WHERE first = '#{first}' AND last = '#{last}']
    QuestionsDatabase.instance.execute(query).map { |options| User.new(options) }
  end

  def create
    query = %Q[
      INSERT INTO
        users (first, last)
      VALUES
        (?, ?);]
    QuestionsDatabase.instance.execute(query, first, last)
    @user_id = QuestionsDatabase.instance.last_insert_row_id
    self
  end

  def save
    query = %Q[
      UPDATE users
      SET first = '#{@first}',
          last = '#{@last}'
      WHERE user_id = #{@user_id}]
    QuestionsDatabase.instance.execute(query)
    self
  end

  def authored_questions
    query = %Q[
      SELECT * FROM
        questions
      WHERE
        author_id = #{@user_id}]
    QuestionsDatabase.instance.execute(query).map { |options| Question.new(options) }
  end

  def followed_questions
    QuestionFollower.followed_questions_for_user_id(@user_id)
  end

  def authored_replies
    Reply.find_by_user_id(@user_id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(@user_id)
  end

end

class Question

  attr_accessor :question_id, :title, :body, :author_id

  def initialize(options = {})
    @question_id = options["question_id"]
    @title = options["title"]
    @body = options["body"]
    @author_id = options["author_id"]
  end

  def Question.find_by_id(id_to_find)
    query = %Q[
      SELECT * FROM
        questions
      WHERE question_id = #{id_to_find};]
    Question.new(QuestionsDatabase.instance.execute(query)[0])
  end

  def Question.find_by_author_id(author_id)
    query = %Q[
      SELECT * FROM
        questions
      WHERE author_id = '#{author_id}';]
    QuestionsDatabase.instance.execute(query).map { |options| Question.new(options) }
  end

  def create
    QuestionsDatabase.instance.execute(<<-SQL, title, body, author_id)
      INSERT INTO
        questions (title, body, author_id)
      VALUES
        (?, ?, ?);
        SQL
    @question_id = QuestionsDatabase.instance.last_insert_row_id
    return self
  end

  def author
    User.find_by_id(@author_id)
  end

  def replies
    Reply.find_by_question_id(@question_id)
  end

  def followers
    QuestionFollower.followers_for_question_id(@question_id)
  end

  def likers
    QuestionLike.likers_for_question_id(@question_id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(@question_id)
  end

end

class Reply

  attr_accessor :reply_id, :question_id, :parent_id, :body, :author_id

  def initialize(options = {})
    @reply_id = options["reply_id"]
    @question_id = options["question_id"]
    @parent_id = options["parent_id"]
    @body = options["body"]
    @author_id = options["author_id"]
  end

  def Reply.find_by_id(id_to_find)
    query = %Q[
      SELECT * FROM
        replies
      WHERE reply_id = #{id_to_find};]
    Reply.new(QuestionsDatabase.instance.execute(query)[0])
  end

  def Reply.find_by_question_id(id_to_find)
    query = %Q[
      SELECT * FROM
        replies
      WHERE question_id = #{id_to_find};]
    QuestionsDatabase.instance.execute(query).map { |options| Reply.new(options) }
  end

  def Reply.find_by_author_id(id_to_find)
    query = %Q[
      SELECT * FROM
        replies
      WHERE author_id = #{id_to_find};]
    QuestionsDatabase.instance.execute(query).map { |options| Reply.new(options) }
  end

  def create
    query = %Q[
      INSERT INTO
        replies (question_id, parent_id, body, author_id)
      VALUES
        (?, ?, ?, ?);]
    QuestionsDatabase.instance.execute(query, question_id, parent_id, body, author_id)
    @reply_id = QuestionsDatabase.instance.last_insert_row_id
    return self
  end

  def author
    User.find_by_id(@author_id)
  end

  def question
    Question.find_by_id(@question_id)
  end

  def parent_reply
    Reply.find_by_id(@parent_id)
  end

  def child_replies
    query = %Q[
      SELECT * FROM
        replies
      WHERE parent_id = #{@reply_id};]
    QuestionsDatabase.instance.execute(query).map { |options| Reply.new(options) }
  end

  def Question.most_followed(n)
    QuestionFollower.most_followed_questions(n)
  end

end

class QuestionFollower
  def QuestionFollower.followers_for_question_id(id_to_find)
    query = %Q[
      SELECT user_id, first, last
      FROM users JOIN question_followers ON user_id = follower_id
      WHERE question_id = #{id_to_find}; ]
    QuestionsDatabase.instance.execute(query).map { |options| User.new(options) }
  end

  def QuestionFollower.followed_questions_for_user_id(id_to_find)
    query = %Q[
      SELECT questions.question_id, title, body, author_id
      FROM questions JOIN question_followers ON questions.question_id = question_followers.question_id
      WHERE follower_id = #{id_to_find}; ]
    QuestionsDatabase.instance.execute(query).map { |options| Question.new(options) }
  end

  def QuestionFollower.most_followed_questions(n)
    query = %Q[
      SELECT questions.question_id, title, body, author_id
         FROM
           questions JOIN question_followers
             ON questions.question_id = question_followers.question_id
         GROUP BY question_followers.question_id
         ORDER BY COUNT(question_followers.question_id) DESC; ]
    QuestionsDatabase.instance.execute(query)[0...n].map { |options| Question.new(options) }
  end

end

class QuestionLike

  def QuestionLike.likers_for_question_id(question_id)
    query = %Q[
      SELECT users.user_id, first, last
      FROM users JOIN question_likes ON users.user_id = question_likes.user_id
      WHERE question_id = #{question_id}; ]
    QuestionsDatabase.instance.execute(query).map { |options| User.new(options) }
  end

  def QuestionLike.num_likes_for_question_id(question_id)
    query = %Q[
      SELECT COUNT(question_likes.question_id)
      FROM questions JOIN question_likes ON questions.question_id = question_likes.question_id
      WHERE questions.question_id = #{question_id}
      GROUP BY question_likes.question_id;]
    query_result = QuestionsDatabase.instance.execute(query)
    unless query_result.empty?
      return query_result[0].values[0]
    else
      return 0
    end
  end

  def QuestionLike.liked_questions_for_user_id(user_id)
    query = %Q[
      SELECT questions.question_id, title, body, author_id
      FROM questions JOIN question_likes ON questions.question_id = question_likes.question_id
      WHERE user_id = #{user_id}; ]
    QuestionsDatabase.instance.execute(query).map { |options| Question.new(options) }
  end

  def QuestionLike.most_liked_questions(n)
    query = %Q[
      SELECT questions.question_id, title, body, author_id
         FROM
           questions JOIN question_likes
             ON questions.question_id = question_likes.question_id
         GROUP BY question_likes.question_id
         ORDER BY COUNT(question_likes.question_id) DESC; ]
    QuestionsDatabase.instance.execute(query)[0...n].map { |options| Question.new(options) }
  end

  def QuestionLike.average_karma_for_user_id(user_id)
    query = %Q[
    SELECT CAST(COUNT(question_likes.user_id) AS FLOAT)/COUNT(DISTINCT q.question_id)
    FROM (SELECT question_id FROM questions WHERE author_id = #{user_id}) AS q
      JOIN question_likes ON q.question_id = question_likes.question_id;]
    QuestionsDatabase.instance.execute(query)[0].values[0]
  end

end