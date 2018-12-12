function [value,known_product] = isProductInstalled( productName, licenseName )
% isProductInstalled - Determine if a product is installed and licensed
%
% [installed_and_licensed,known_product] = isProductInstalled( productOrLicenseName)
%
% productOrLicenseName is the full name of the product, as shown by the
%   "ver" command, or the name of a FLEX license.
% installed_and_licensed is a logical scalar and is true if the product is
%   licensed and installed.
% known_product is a logical scalar and is true if productOrLicenseName
%   is recognised by this function.
%
% If MATLAB is running with Java disabled, then specify a second
% input, flexLicenseName, and the function provides a single output:
%
% installed_and_licensed = isProductInstalled( productName, flexLicenseName)
%

% Copyright 2014-2016 The Mathworks, Inc.

    if usejava( 'jvm' )
        productInfo = com.mathworks.product.util.ProductIdentifier.get( productName );
        known_product = ~isempty(productInfo);
    else
        productInfo.getName = productName;
        productInfo.getFlexName = licenseName;
        % We deliberately don't return a second output here, to help avoid
        % accidental misuse.
    end
    
    if ~isempty( productInfo )
        % Check whether a license is available for this product.
        value = logical(license( 'test', char(productInfo.getFlexName) ));
        if value
            % Check whether the product is installed.
            productNames = getProductNames;
            value = any( strcmpi( char( productInfo.getName ), productNames ) );
        end
    else
        value = false;
    end
    
end

function value = getProductNames()
    persistent productNames;
    
    if isempty( productNames )
        if usejava( 'jvm' )
            productList = com.mathworks.install.InstalledProductFactory.getInstalledProducts(matlabroot);
        else
            productList = [];
        end

        % Matlab installer is only available in installed MATLAB. Otherwise, the installer
        % will return a productList with size 0. In this case, we fall back to ver.
        if ~isempty( productList ) && productList.size > 0
            productNames = cell( 1, productList.size );
            for index = 1:productList.size
                product = productList.get(index-1);
                productNames{index} = char( product.getName );
            end
        else
            versionInfo = ver;
            productNames = { versionInfo.Name };
        end
    end
    
    value = productNames;
end