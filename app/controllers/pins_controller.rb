class PinsController < ApplicationController
  before_action :authenticate_user!

  def index
    @limit = [1, params[:limit].to_i, 1000].sort[1]
    statuses = params[:status].to_s.split(',')
    @status = statuses.select{|s| Pin::STATUSES.include?(s)}
    @status = 'pinned' if @status.blank?
    @scope = current_user.pins.not_deleted.order('created_at DESC').status(@status)

    @scope = @scope.name_contains(params[:name]) if params[:name].present?
    @scope = @scope.cids(params[:cid].split(',')) if params[:cid].present?
    @scope = @scope.before(params[:before]) if params[:before].present?
    @scope = @scope.after(params[:after]) if params[:after].present?
    @scope = @scope.meta(JSON.parse(params[:meta])) if params[:meta].present?

    @count = @scope.count
    @pagy, @pins = pagy(@scope, per: @limit)
  end

  def new
    @pin = current_user.pins.build
  end

  def create
    @pin = current_user.pins.build(pin_params)
    if @pin.save
      @pin.ipfs_add_async
      redirect_to @pin
    else
      render :new
    end
  end

  def destroy
    @pin = current_user.pins.not_deleted.find(params[:id])
    @pin.ipfs_remove_async
    @pin.mark_deleted
    redirect_to pins_path
  end

  def show
    @pin = current_user.pins.not_deleted.find(params[:id])
  end

  def update
    @existing_pin = current_user.pins.not_deleted.find(params[:id])
    @pin = current_user.pins.build(pin_params)
    if @pin.save!
      @pin.ipfs_add_async
      @existing_pin.ipfs_remove_async
      @existing_pin.mark_deleted
      redirect_to @pin
    else
      render :edit
    end
  end

  def edit
    @pin = current_user.pins.find(params[:id])
  end

  protected

  def pin_params
    params.require(:pin).permit(:cid, :name)
  end
end
