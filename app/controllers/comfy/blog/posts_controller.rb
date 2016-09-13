class Comfy::Blog::PostsController < Comfy::Blog::BaseController
  include Comfy::LiquidContentHelper

  skip_before_action :load_blog, :only => [:serve]

  # due to fancy routing it's hard to say if we need show or index
  # action. let's figure it out here.
  def serve
    # if there are more than one blog, blog_path is expected
    if @cms_site.blogs.count >= 2
      params[:blog_path] = params.delete(:slug) if params[:blog_path].blank?
    end

    load_blog

    if params[:slug].present?
      show && render(:show)
    else
      index && render(:index)
    end
  end

  def index
    scope = if params[:year]
      scope = @blog.posts.published.for_year(params[:year])
      params[:month] ? scope.for_month(params[:month]) : scope
    else
      @blog.posts.published
    end

    limit = ComfyBlog.config.posts_per_page
    respond_to do |format|
      format.html do
        @posts = comfy_paginate(scope, limit)
      end
      format.rss do
        @posts = scope.limit(limit)
      end
    end
  end

  def show
    @post = if params[:slug] && params[:year] && params[:month]
      @blog.posts.published.where(:year => params[:year], :month => params[:month], :slug => params[:slug]).first!
    else
      @blog.posts.published.where(:slug => params[:slug]).first!
    end
    @comment = @post.comments.new

    respond_to do |format|
      format.html { render_page }
      # format.json { render :json => @cms_page }
    end

    return

  rescue ActiveRecord::RecordNotFound
    render :cms_page => '/404', :status => 404
  end

protected
 def mime_type
    'text/html'
  end

  def render_page(status = 200)
    cms_layout = Comfy::Cms::Layout.where(identifier: 'news').first
    if @cms_layout = cms_layout

      p cms_layout
      

      app_layout = (@cms_layout.app_layout.blank? || request.xhr?) ? false : @cms_layout.app_layout
      p app_layout
      p ::ComfortableMexicanSofa::Tag.process_content(
        @post, ::ComfortableMexicanSofa::Tag.sanitize_irb(cms_layout.merged_content)
      )

      render  :inline       => liquid_parse(@post.content),
              :layout       => app_layout,
              :status       => status,
              :content_type => mime_type
    else
      render :text => I18n.t('comfy.cms.content.layout_not_found'), :status => 404
    end
  end
end