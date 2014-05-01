class BillsController < ApplicationController
  before_action :set_bill, only: [:show, :edit, :update, :destroy]

  # GET /bills
  # GET /bills.json
  def index
    @bills_grid = initialize_grid(
      Bill.unscoped.joins("INNER JOIN userbills ON userbills.bill_id = bills.id INNER JOIN users ON userbills.user_id = users.id").where("users.id = ?", current_user.id),
      order:           'bills.date',
      order_direction: 'desc',
      per_page: 20
    )

    @all_records = []

    @bills_grid.with_resultset do |records|
      records.each{|rec| @all_records << rec}
    end

  end

  # GET /bills/1
  # GET /bills/1.json
  def show
  end

  # GET /bills/new
  def new
    @bill = Bill.new
  end

  # GET /bills/1/edit
  def edit
  end

  # POST /bills
  # POST /bills.json
  def create
    @bill = Bill.new(bill_params)

    respond_to do |format|
      if @bill.save
        current_user.userbills.create!(bill_id: @bill.id)
        @bill.create_activity :create, owner: current_user, parameters: Hash["consumption" => @bill.consumption, "value" => @bill.value, "time" => @bill.created_at.strftime("%b %Y")]
      
        alerts
              
        format.html { redirect_to profile_path, notice: 'Bill was successfully created.' }
        format.json { render action: 'show', status: :created, location: @bill }
      else
        format.html { render action: 'new' }
        format.json { render json: @bill.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /bills/1
  # PATCH/PUT /bills/1.json
  def update
    respond_to do |format|
      if @bill.update(bill_params)
        @bill.create_activity :update, owner: current_user, parameters: Hash["consumption" => @bill.consumption, "value" => @bill.value, "time" => @bill.created_at.strftime("%b %Y")]
        format.html { redirect_to @bill, notice: 'Bill was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @bill.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bills/1
  # DELETE /bills/1.json
  def destroy
    @bill.destroy
    # @bill.create_activity :destroy, owner: current_user
    respond_to do |format|
      format.html { redirect_to :back }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_bill
      @bill = Bill.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def bill_params
      params.require(:bill).permit(:consumption, :value, :service, :date)
    end

    def alerts

      avg_bills_yours = Bill.joins("INNER JOIN userbills ON userbills.bill_id = bills.id INNER JOIN users ON userbills.user_id = users.id").where("users.id = ?", current_user.id).average("consumption")
    
      avg_bills_friends = Bill.joins("INNER JOIN userbills ON userbills.bill_id = bills.id INNER JOIN users ON userbills.user_id = users.id INNER JOIN friendships ON (users.id = friendships.friendable_id OR users.id = friendships.friend_id)").where('users.id not IN (?) AND (friendships.friendable_id= ? OR friendships.friend_id = ?) AND friendships.pending = 0 AND friendships.blocker_id IS NULL', current_user.id, current_user.id, current_user.id).average("consumption").to_i

      avg_bills_tariff = Bill.joins("INNER JOIN userbills ON userbills.bill_id = bills.id INNER JOIN users ON userbills.user_id = users.id INNER JOIN friendships ON (users.id = friendships.friendable_id OR users.id = friendships.friend_id)").where('users.id not IN (?) AND (friendships.friendable_id= ? OR friendships.friend_id = ?) AND friendships.pending = 0 AND friendships.blocker_id IS NULL AND users.tariff = ?', current_user.id, current_user.id, current_user.id, current_user.tariff).average("consumption")

      avg_bills_neighbors = Bill.joins("INNER JOIN userbills ON userbills.bill_id = bills.id INNER JOIN users ON userbills.user_id = users.id INNER JOIN friendships ON (users.id = friendships.friendable_id OR users.id = friendships.friend_id)").where('users.id not IN (?) AND (friendships.friendable_id= ? OR friendships.friend_id = ?) AND friendships.pending = 0 AND friendships.blocker_id IS NULL AND users.address = ?', current_user.id, current_user.id, current_user.id, current_user.address).average("consumption")

      create_alert if @bill.consumption > 2.05*avg_bills_friends or @bill.consumption > 1.8*avg_bills_tariff or @bill.consumption > 1.65*avg_bills_neighbors or @bill.consumption > 1.5*avg_bills_yours 

    end

    def create_alert
      PublicActivity::Activity.create!({
            :trackable_id =>@bill.id,
            :trackable_type => "Bill",
            :owner_id => current_user.id,
            :owner_type => "User",
            :key => "bill.alert",
            :parameters => Hash["consumption" => @bill.consumption, "value" => @bill.value, "time" => @bill.created_at.strftime("%b %Y")]
            })
    end

end
