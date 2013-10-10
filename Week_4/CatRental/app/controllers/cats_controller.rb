class CatsController < ApplicationController

  def index
    @cats = Cat.all
    render :index
  end

  def new
    @cat = Cat.new
    render :new
  end

  def create
    @cat = Cat.new(params[:cat])
    if @cat.save
      #render cats_url(@cat.id)
      render :show
    else
      render :json => "ERROR CREATING CAT"
    end
  end

  def show
    @cat = Cat.find(params[:id])
    render :show
  end

  def edit
  end

  def update
  end

  def destroy

  end

end