class Builder::SitesController < BuilderController

  before_filter :set_layout_options

  def index
  end

  def show
  end

  def new
    @current_site = Site.new
  end

  def create
    @current_site = Site.new(create_params)
    if current_site.save
      SiteUser.create!(:user => current_user, :site => current_site, 
        :site_admin => true)
      redirect_to(route([current_site], :show), 
        :notice => t('notices.created', :item => "Site")) 
    else
      render('new')
    end
  end

  def edit
    current_site = current_site
  end

  def update
    if current_site.update(update_params)
      redirect_to(route([current_site], :edit), 
        :notice => t('notices.updated', :item => "Site")) 
    else
      render('edit')
    end
  end

  private

    def create_params
      params.require(:site).permit(
        :title, 
        :url, 
        :description,
        :home_page_id,
        :image_croppings_attributes => [
          :id, 
          :title,
          :ratio,
          :min_width,
          :min_height
        ]
      )
    end

    def update_params
      create_params
    end

    def set_layout_options
      if ['index', 'new', 'create'].include?(action_name)
        @options['sidebar'] = false
        @options['body_classes'] += ' my-sites'
      end
    end

end